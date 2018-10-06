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
        children: params[:sub_repos]&.map { |subrepo| PullRequest.from_params(subrepo) },
        sub_repo_actions: SubRepoAction.from_params_list(params[:sub_repo_actions])
      ))
      pr.children.each { |child| child.parent = pr }
      pr
    end

    def from_parent_decoding(decoded)
      new(
        repository: Repository.from_name(decoded[:parent]),
        id: decoded[:parent_id]
      )
    end

    def from_pull_request(pull_request)
      return if pull_request.nil?
      decoded = MegaMerge::ParentDecoder.decode(pull_request[:body]) ||
                MegaMerge::ParentDecoderOld.decode(pull_request[:body]) # check if we have old metadata here
      return nil if decoded.nil?
      pr = MetaPullRequest.from_github_data(pull_request)
      pr.fill_from_decoded!(decoded)
    end

    def shadow_branch(branch)
      "#{branch}#{SHADOW_BRANCH_SUFFIX}"
    end
  end

  def fill_from_decoded!(decoded)
    return self if decoded.nil?
    @body = decoded[:body]
    @squash = decoded[:config][:squash]
    @source_branch = decoded[:config][:source_branch]
    @config_file = decoded[:config][:config_file]
    @sub_repo_actions = decoded[:config][:sub_repo_actions]&.transform_values! do |sub_repo|
      SubRepoAction.from_params(sub_repo)
    end
    @children = decoded[:config][:children].map do |child|
      PullRequest.from_child_decoding(child.symbolize_keys, self)
    end
    self
  end

  attr_reader :config_file
  attr_writer :children, :sub_repo_actions

  def file
    @file ||= MegaMerge::MetaRepository.config_file(config_file, repository, shadow_branch)
  end

  def target_file
    @target_file ||= MegaMerge::MetaRepository.config_file(config_file, repository, target_branch)
  end

  def config_file=(value)
    @config_file = value
    @file = nil
  end

  def title
    @title.presence || "#{source_presentation}: #{source_branch} -> #{target_branch}"
  end

  def source_presentation
    source_branch&.split('/')&.last&.upcase
  end

  def shadow_branch
    @shadow_branch.presence || source_branch + SHADOW_BRANCH_SUFFIX
  end

  def sub_repo_actions
    @sub_repo_actions || {}
  end

  def child_actions
    sub_repo_actions.merge(SubRepoAction.from_pr_list(children))
  end

  def children
    @children || []
  end

  def done?
    merged? || closed?
  end

  def megamergeable?
    super && children_megamergeable?
  end

  def children_megamergeable?
    children.all?(&:megamergeable?)
  end

  def children_outdated?
    return false unless source_branch_exists? && !closed?

    @children_outdated ||= children.any? do |child|
      file.projects[child.repository.name] &&
        file.projects[child.repository.name].revision != child.merge_commit_sha
    end
  end
end
