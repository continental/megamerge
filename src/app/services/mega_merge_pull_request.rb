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
  end

  def call
    old_pr_state = old_meta_pr
    return nil if !old_meta_pr && @pull_id && !@config_file
    return old_pr_state if old_pr_state
    open_pr = repository.find_open_pr(MetaPullRequest.shadow_branch(@source_branch), @target_branch)

    if open_pr&.id?
      open_pr = PullRequest.from_github_data(repository.pull_request(open_pr.id)) if open_pr.state_unknown?
      open_pr.source_branch = open_pr.source_branch.remove(MetaPullRequest::SHADOW_BRANCH_SUFFIX)
      MetaPullRequest.create(open_pr, config_file: @config_file)
    else
      MetaPullRequest.from_params(@params)
    end
  end

  private

  def pull_request
    @pull_request ||= repository.pull_request(@pull_id) if PullRequest.id?(@pull_id)
  end

  def old_meta_pr
    @old_meta_pr ||= MetaPullRequest.from_pull_request(pull_request)
  end

  def repository
    @repository ||= Repository.new(organization: @org, repository: @repo)
  end
end
