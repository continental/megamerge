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

class MegaMergePullRequest
  include Callable

  def initialize(params)
    @params = params
    @org = params[:organization]
    @repo = params[:repository]
    @source_branch = params[:source_branch]
    @target_branch = params[:target_branch]
    @pull_id = params[:pull_id].to_i
    @config_file = params[:config_file]
    params[:source_repo_full_name] = @org + "/" + @repo if params[:source_repo_full_name].nil?
    @source_repository = Repository.from_name(params[:source_repo_full_name])
  end

  # params: none
  # description: Creates a new pull request and returns it if it does not already exist,
  #              if it does returns an already existing one
  # return: nil if no old_pr_state and no pr config_file
  # return: old_pr_state if old_pr_state exists
  # return: new MetaPullRequest
  # return: existing MetaPullRequest
  # exception: MegamergeException if before MetaPullRequest creation pr exists already
  def call
    old_pr_state = old_meta_pr
    return nil if !old_meta_pr && @pull_id && !@config_file
    return old_pr_state if old_pr_state
    open_pr = repository.find_open_pr(@source_repository, @source_branch, @target_branch)

    if open_pr&.id?
      open_pr = PullRequest.from_github_data(repository.pull_request(open_pr.id)) if open_pr.state_unknown?
      raise MegamergeException, "This Megamerge Pull Request exists already!" unless parent_body(open_pr).nil?
      MetaPullRequest.create(open_pr, config_file: @config_file)
    else
      MetaPullRequest.from_params(@params)
    end
  end

  private

  def parent_body(pull_request)
    MegaMerge::ParentDecoder.decode(pull_request.body)
  end

  def pull_request
    @pull_request ||= repository.pull_request(@pull_id) if PullRequest.id?(@pull_id)
  end

  def old_meta_pr
    @old_meta_pr ||= MetaPullRequest.load(@org, @repo, @pull_id)
  end

  def repository
    @repository ||= Repository.new(organization: @org, repository: @repo)
  end
end
