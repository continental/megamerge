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

# Represents the pull request github pull requests. By default
# this will be populated as a `Child pull request`.
# All state in relation to a mega merge pull request should be put here.
# The actions performed by a pull request can be found under `pull_request/actions.rb`
class PullRequest < BaseModel
  include PullRequest::Actions

  def self.from_params(params)
    pr = new(keep_attributes(params))
    
    pr.id = params[:pull_id]
    pr.repository = Repository.new(organization: params[:organization], repository: params[:repository]) if pr.repository.kind_of?(String)
    pr.source_repository = Repository.from_name(params[:source_repo_full_name])
    pr.merge_method = params[:merge_method]
    pr.config_files = params[:config_files] ? params[:config_files] : params[:config_file]
    pr
  end

  def self.from_github_data(data)
    repo = Repository.from_github_data(data[:base][:repo])
    new(
      id: data[:number],
      repository: repo,
      title: data[:title],
      body: data[:body],
      source_branch: data[:head][:ref],
      source_branch_sha: data[:head][:sha],
      source_repository: Repository.from_github_data(data[:head][:repo]),
      target_branch: data[:base][:ref],
      mergeable: data[:mergeable],
      rebaseable: data[:rebaseable],
      merged: data[:merged],
      mergeable_state: data[:mergeable_state],
      merge_commit_sha: data[:merge_commit_sha],
      state: data[:state],
      author: User.from_github_data(repo.client, data[:user]),
      object_id: data[:node_id],
      draft: data[:draft]
    )
  end

  def self.from_gql(data)
    logger.info "pr from gql #{data[:number]}"
    source_repo = repo = Repository.from_gql(data[:baseRepository])
    source_repo = Repository.from_name(data[:headRepository][:nameWithOwner]) unless data[:baseRepository][:nameWithOwner].eql? data[:headRepository][:nameWithOwner]
    pr = new(
      id: data[:number],
      repository: repo,
      title: data[:title],
      body: data[:body],
      source_branch: data[:headRefName],
      source_branch_sha: data[:headRefOid],
      source_branch_object_id: data.dig(:headRef, :id),
      source_repository: source_repo,
      target_branch: data[:baseRefName],
      mergeable: data[:mergeable].downcase,
      rebaseable: data[:canBeRebased],
      merged: data[:merged],
      mergeable_state: data[:mergeStateStatus].downcase,
      merge_commit_sha: data[:mergeCommit].nil? ? data.dig(:potentialMergeCommit, :oid) : data.dig(:mergeCommit, :oid),
      state: data[:state].downcase,
      author: User.from_gql(repo.client, data[:author]),
      object_id: data[:id],
      required_checks: [
          data[:baseRef].dig(:refUpdateRule, :requiredStatusCheckContexts),     # filled only in non-admin
          data[:baseRef].dig(:branchProtectionRule, :requiredStatusCheckContexts)  # filled only in admin
        ].compact.reduce([], :|), # remove nil and duplicates and flatten the resulting array
      review_decision: data[:reviewDecision]&.downcase,
      commits: data[:commits][:nodes],
      draft: data[:isDraft]
    )
    
    # api v3 compatible
    pr.commits.each{|commit| commit[:sha] = commit[:commit][:sha]}

    pr
  end

  attr_writer :target_branch, :source_branch, :shadow_branch
  attr_writer :source_branch_sha, :source_repository, :merge_method

  attr_accessor :repository, :title, :body, :parent, :merge_commit_message, :commits, :merge_commit_sha
  attr_accessor :merged, :mergeable, :rebaseable, :mergeable_state, :state, :author, :object_id, :review_decision
  attr_accessor :source_branch_object_id, :draft, :config_files, :required_checks, :merge_method

  attribute_method_suffix '?'
  define_attribute_methods :merged, :removeable, :parent

  validates! :repository, presence: true
  validates :id, pull_request_number: true

  def id
    @id || 0
  end

  def id=(value)
    @id = value.to_i.positive? ? value.to_i : 0
  end

  def self.id?(value)
    value.present? && value.to_i.positive?
  end

  def simple_name
    slug.gsub(/[^0-9A-Za-z]/, '')
  end

  def id?
    self.class.id?(id)
  end

  def merge_commit_sha
    return @merge_commit_sha unless @merge_commit_sha.nil?
    return 0 unless id?

    @merge_commit_sha ||= repository.pull_request(id)[:merge_commit_sha]
  end

  def exists?
    id? && repository.pull_request_exists?(id)
  end

  def full_identifier
    # return array of full_identifier forall config_files in array

    # Needs to be @var, not local var, else ruby looses access to the variable (sometimes, not sure why).
    # It will be and array and nil in this method, always the opposite of what you need.
    # https://stackoverflow.com/questions/7208768/is-it-possible-to-use-pointers-in-ruby
    # repository.name + "/" + config_files.to_s

    fi = []
    @config_files = JSON.parse @config_files unless @config_files.kind_of?(Array)
    @config_files.map { |file| 
    file = file.to_s.gsub(',', ',' + ' ' + repository.name + '/')  
    fi.push(repository.name + "/" + file.to_s) }
    fi
  end


  def from_fork?
    repository.name != source_repository.name
  end

  def source_repository
    @source_repository ||= repository
  end

  def target_branch
    @target_branch || repository.default_branch
  end

  def removeable
    @removeable || false
  end

  def removeable=(value)
    @removeable = (value.is_a?(String) && value == 'true') || (!!value == value && value)
  end

  def draft?
    return draft.to_b unless draft.nil?
    true
  end

  def merge_method
    return @merge_method unless @merge_method.nil?
    @merge_method = "MERGE" if repository.allow_merge_commit
    @merge_method = "REBASE" if repository.allow_rebase_merge
    @merge_method = "SQUASH" if repository.allow_squash_merge   # last returned is default value for GUI
    @merge_method
  end

  def status
    return @status unless @status.nil?

    @status ||=
      if id?
        existing_status
      elsif shadow_branch_exists? && !source_branch_has_mergeable_commits?
        { text: 'Source and Target are the same', color: 'danger', blocking: true }
      else
        { text: 'OK', color: 'muted' }
      end
  end

  def create_gql_set_draft_state(state)

    hash = "h_" +SecureRandom.alphanumeric(10)

    if false # convertPullRequestToDraft not supported by our server?!
      "
      #{hash}: convertPullRequestToDraft(
        input: {pullRequestId: \"#{object_id}\"}
      ){ clientMutationId }
      "
    elsif state == false
      "
      #{hash}: markPullRequestReadyForReview(
        input: {pullRequestId: \"#{object_id}\"}
      ){ clientMutationId }
      "
    end
  end

  def self.create_gql_query(key, repoFullName, pullId, fields = nil)
    org, repo = repoFullName.split('/')

    fields = gql_pr_fields if fields.nil?
    query =
      "#{key}: repository(owner: \"#{org}\", name: \"#{repo}\") {
        pullRequest(number: #{pullId}) {
        " + fields + "
        }
      }"
  end

  def self.gql_pr_fields
    "
    title
    body
    id
    number
    headRefName
    headRefOid
    headRef {
      id
    }
    headRepository {
      nameWithOwner
    }
    baseRef {
      refUpdateRule {
        requiredStatusCheckContexts   
      }
      branchProtectionRule  {
        requiredStatusCheckContexts  
      }
    }
    baseRefName
    baseRepository {
    " + Repository.gql_query_params + "
    }
    author {
      login
    }
    isDraft
    mergeable
    canBeRebased
    merged
    mergeStateStatus
    mergeCommit {
      oid
    }
    potentialMergeCommit  {
      oid
    }
    state
    reviewDecision 
    commits(first: 250) {
      nodes {
        commit {
          message
          sha: oid
          tree {
            sha: oid
          }
        }
      }
    }
    "
  end

  def source_branch
    @source_branch.presence || source_repository.default_branch
  end

  def shadow_branch
    source_branch
  end

  def source_branch_exists?
    @source_branch_exists ||= source_repository.branch_exists?(source_branch)
  end

  def shadow_branch_exists?
    source_branch_exists?
  end

  def source_branch_has_mergeable_commits?
    repository.branch_ahead?(target_branch, source_repository.owner + ":" + shadow_branch)
  end

  def commits
    @commits ||= repository.pull_request_commits(id)
  end

  def slug(delim: '/')
    "#{repository.name}#{delim}#{id}"
  end

  def md_link
    "[#{slug(delim: '#')}](#{Rails.application.config.github[:server]}/#{slug(delim: '/pull/')})"
  end

  def self.branch_slug(repo, source, target)
    sb = ERB::Util.url_encode(source)
    tb = ERB::Util.url_encode(target)
    "#{repo.name}/#{sb}/#{tb}"
  end

  def branch_slug
    self.class.branch_slug(repository, source_branch, target_branch)
  end

  def state_unknown?
    mergeable_state == 'unknown'
  end

  def blocked?
    mergeable_state == 'blocked'
  end

  def dirty?
    mergeable_state == 'dirty'
  end

  def behind?
    mergeable_state == 'behind'
  end

  def closed?
    state == 'closed'
  end

  def changes_requested?
    review_decision == 'changes_requested'
  end

  def pending_review?
    review_decision == 'review_required'
  end

  def reviews_done?
    review_decision.nil? || review_decision == 'approved'
  end

  def saveable?
    !status[:blocking]
  end

  def mergeable?
    return false if id == 0 || merged? || closed?

    4.times { |c|
      res = check_mergeable
      return res unless res.nil?
      logger.info("Mergable was not yet computed by GitHub")
      sleep(2 * c)
      GitHub::GQL.add(repository.name, GitHub::GQL.QUERY, PullRequest.create_gql_query('mergeable', repository.name, id, 'mergeable'))
      (self.mergeable = GitHub::GQL.execute[:mergeable][:pullRequest][:mergeable].downcase)
    }
    nil
  end

  def check_mergeable
    if mergeable.bool?
      mergeable
    elsif mergeable == 'true' || mergeable == 'mergeable'
      true
    elsif mergeable == 'false' || mergeable == 'conflicting'
      false
    elsif mergeable == 'null' || mergeable == 'nil' || mergeable == 'unknown'
      nil
    end
  end

  def megamergeable?
    mergeable? && !blocked? && !dirty? && !closed? && !behind? && !draft? && !state_unknown?
  end

  def rebaseable?
    return false if id == 0 || merged? || closed?

    4.times { |c|
      return rebaseable if rebaseable.bool?
      logger.info("Rebaseable was not yet computed by GitHub")
      sleep(2 * c)
      GitHub::GQL.add(repository.name, GitHub::GQL.QUERY, PullRequest.create_gql_query('canBeRebased', repository.name, id, 'canBeRebased'))
      (self.rebaseable = GitHub::GQL.execute[:canBeRebased][:pullRequest][:canBeRebased])
    }
    nil
  end

  def merge_conflict?
    !mergeable? && dirty?
  end

  def source_branch_sha
    @source_branch_sha ||= repository.commit(source_branch).sha
  end

  def status_collection
    @status_collection ||= PullRequestStatuses.from_github_data(repository.combined_status(source_branch_sha))
  end

  def pr_reviews
    @pr_reviews ||= PullRequestReviews.from_github_data(repository.pull_request_reviews(id))
  end

  def readable_mergeability
    <<~TEXT
      #{slug}
      -- mergeable => #{mergeable?}
      -- mergeable_state => #{mergeable_state}
      -- blocked => #{blocked?}
      -- dirty => #{dirty?}
      -- closed => #{closed?}
      -- behind => #{behind?}
      -- reviews_done => #{reviews_done?}
      -- review_decision => #{review_decision}
      -- draft => #{draft?}
      -- unknown => #{state_unknown?}
      -- rebaseable => #{rebaseable?}
    TEXT
  end

  private

  def existing_status
    if merged?
      { text: 'Merged', color: 'success' }
    elsif closed?
      { text: 'Closed', color: 'danger' }
    elsif merge_conflict?
      { text: 'Merge conflicts', color: 'danger' }
    elsif draft?
      { text: 'PR is in draft state', color: 'warning' }
    elsif mergeable? && blocked?
      if pending_review?
        { text: 'Waiting for review', color: 'warning' }
      elsif changes_requested?
        { text: 'Review requested changes', color: 'warning' }
      elsif required_checks.nil?
        { text: '?', color: 'muted' }
      elsif status_collection.missing_checks(required_checks).present?
        {
          text: 'Waiting for status checks',
          color: 'warning',
          checks: status_collection.missing_checks(required_checks)
        }
      else
        { text: 'No rights to merge', color: 'danger' }
      end
    elsif mergeable? && behind?
      { text: 'Branch is behind', color: 'danger' }
    elsif mergeable?
      { text: 'Will be merged', color: 'info' }
    elsif mergeable?.nil?
      { text: 'GitHub is still computing', color: 'warning' }
    else
      { text: 'Unknown', color: 'danger' }
    end
  end

  def attribute?(attribute)
    !!send(attribute)
  end
end
