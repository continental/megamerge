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

class SaveMegaMergeState
  include Callable

  def initialize(user, meta_repo, sub_repos, sub_repo_actions)
    @user = user
    @meta_repo = meta_repo
    @sub_repos = sub_repos
    @sub_repo_actions = sub_repo_actions
  end

  def call
    if old_meta_pr
      return old_meta_pr if old_meta_pr.id? && old_meta_pr.done?

      old_meta_pr.close_stale_children!(meta_pr.children)
    end
    with_flock do
      meta_pr.create_children_as_user!(user)
      meta_pr.update_state!
      meta_pr.create_as_user!(user)
      meta_pr.write_state!
    end
    meta_pr
  end

  private

  attr_reader :user

  def pull_request
    @pull_request ||= repository.pull_request(@meta_repo[:pull_id]) if PullRequest.id?(@meta_repo[:pull_id])
  end

  def old_meta_pr
    @old_meta_pr ||= MetaPullRequest.from_pull_request(pull_request)
  end

  def repository
    @repository ||= Repository.from_params(@meta_repo)
  end

  def meta_pr
    @meta_pr ||= MetaPullRequest.from_params(@meta_repo.merge(sub_repos: @sub_repos, sub_repo_actions: @sub_repo_actions))
  end
end
