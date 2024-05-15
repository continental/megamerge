# frozen_string_literal: true

# Copyright (c) 2018 Continental Automotive GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Represents a `Meta Pull Request` in the mega merge flow. This pull request
# is responsible for aggregating and synchronizing all the child pull requests.
class MetaPullRequest < PullRequest
  # Need to call it something else than Actions because of naming
  # conflict with `pull_request/actions.rb`
  include MetaPullRequest::MetaActions

  SHADOW_BRANCH_SUFFIX = '_megamerge'

  class << self
    def create(pull_request, config_file: nil)
      new(config_file: config_file).merge_instance!(pull_request)
    end

    def from_params(params)
      pr = super(params.merge!(
        children: params[:sub_repos]&.map { |subrepo| ChildPullRequest.from_params(subrepo) }
      ))
      pr.children.each { |child| child.parent = pr }
      logger.info "from params "
      pr.children_lazy_load = pr.children.map { |child| {:name => child.repository.name, :id => child.id , :merge_method => child.merge_method } }

      pr
    end

    def from_parent_decoding(decoded)
      #logger.info "meta from parent"
      new(
        repository: Repository.from_name(decoded[:parent]),
        id: decoded[:parent_id]
      )
    end

    def from_pull_request(pull_request)
      #logger.info "meta from pr"
      return if pull_request.nil?

      decoded = MegaMerge::ParentDecoder.decode(pull_request[:body])
      return nil if decoded.nil?

      pr = MetaPullRequest.from_github_data(pull_request)
      pr.fill_from_decoded!(decoded)
    end

    def load(org, repo, id)
      return if org.nil? || repo.nil? || !PullRequest.id?(id)

      #logger.info "meta from gql"
      repo_with_owner = org + "/" + repo
      GitHub::GQL.add(repo_with_owner, GitHub::GQL.QUERY, MetaPullRequest.create_gql_query("meta", repo_with_owner, id))
      pr = MetaPullRequest.from_gql(GitHub::GQL.execute[:meta][:pullRequest])

      decoded = MegaMerge::ParentDecoder.decode(pr.body) 
      return nil if decoded.nil?

      pr.fill_from_decoded!(decoded)
    end

    def shadow_branch(_branch)
      source_branch
    end
  end

  def fill_from_decoded!(decoded)
    return self if decoded.nil?

    @body = decoded[:body]
    @merge_method = decoded[:config][:merge_method]
    @automerge = decoded[:config][:automerge]
    @source_branch = decoded[:config][:source_branch]
    @config_file = decoded[:config][:config_file]
    @merge_commit_message = decoded[:config][:merge_commit_message]

    # load children when they are requested
    @children_lazy_load = decoded[:config][:children].map(&:symbolize_keys)

    # fill meta config_file if child does not have one
    # this is needed to make old PRs compatible with the new meta_config during migration to new MM version (3.8)
    @children_lazy_load.each {|child|
      child[:config_file] = @config_file if child[:config_file].nil?
    }

    self
  end

  attr_writer :children, :children_lazy_load, :children_removed
  define_attribute_methods :automerge

  def meta_config  
    return @meta_config unless @meta_config.nil?
    branch = source_branch_exists? ? source_branch : target_branch
    @meta_config = MegaMerge::MetaRepository.create(affected_config_files, repository, branch)
  end

  def title
    @title.presence || ''
  end

  def source_presentation
    source_branch&.split('/')&.last&.upcase
  end

  def shadow_branch
    source_branch
  end

  def children_removed?
    @children_removed
  end

  def children
    return @children unless @children.nil?
    return [] if @children_lazy_load.blank?

    request_string = @children_lazy_load.each { |child| 
      #logger.info "lazy loading: #{child.to_json}"
      GitHub::GQL.add(child[:name], GitHub::GQL.QUERY, ChildPullRequest.create_gql_query("h_#{child.hash.abs}", child[:name], child[:id]) )
    }

    response = GitHub::GQL.execute

      @children = @children_lazy_load.map do |child|
        raise MegamergeException, "Can not open PR: please check your access rights to #{child[:name]} of the pull request" if response["h_#{child.hash.abs}".to_sym].nil?
        ChildPullRequest.from_child_decoding_gql(response["h_#{child.hash.abs}".to_sym][:pullRequest], child, self)
      end


  end


  def body
    return @body if @body
    @body = repository.default_template
  end

  def done?
    merged? || closed?
  end

  def automerge
    @automerge.bool? ? @automerge : true
  end

  def automerge=(value)
    @automerge = if value.bool?
                   value
                 elsif value.is_a? String
                   value != 'false'
                 else
                   true
                 end
  end

  def megamergeable?
    super && children.all?(&:megamergeable?)
  end

  def affected_config_files 
    ([config_file] + children.map(&:config_file)).compact.uniq
  end

  def readable_mergeability
    super + children.map(&:readable_mergeability).join
  end

  def can_rebase_source_branch?
    return false unless id?
    return @can_rebase_source_branch if @can_rebase_source_branch

    # true if all commits are MM commits or merges with the target branch
    @can_rebase_source_branch ||= commits.all? do |commit| 
      commit[:commit][:message].start_with?(MEGAMERGE_COMMIT_PREFIX) ||
      commit[:commit][:message].start_with?("Merge branch '#{target_branch}' into #{source_branch}")
    end
  end

  def remove_subs_possible?
    return true if can_rebase_source_branch?

    latest_user_commit_index = commits.length - 1 - commits.reverse.find_index{ |commit| !commit[:commit][:message].start_with?(MEGAMERGE_COMMIT_PREFIX) }
    first_mm_commit_index = commits.find_index{ |commit| commit[:commit][:message].start_with?(MEGAMERGE_COMMIT_PREFIX) }

    # logger.info "latest user: #{latest_user_commit_index} first mm #{first_mm_commit_index}"

    first_mm_commit_index.nil? || first_mm_commit_index > latest_user_commit_index
  end

  # returns the latest commit in the PR that was done by the user
  def latest_user_commit
    logger.info "commits found: #{commits.count}"
    @latest_user_commit ||= commits.reverse.find { |commit| !commit[:commit][:message].start_with?(MEGAMERGE_COMMIT_PREFIX) }
  end

  def config_outdated?
    return false unless source_branch_exists? && shadow_branch_exists? && !closed?

    meta_config.outdated?(children, self)
  end

  # check if file exists and contains the repo
  def config_inconsistent?
    return false if closed? || merged?

    meta_config.inconsistent?(children)
  end

end
