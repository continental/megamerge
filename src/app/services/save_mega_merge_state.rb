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
  include Loggable

  def initialize(user, meta_repo, sub_repos)
    @user = user
    @meta_repo = meta_repo
    @sub_repos = sub_repos
  end

  def call
    if old_meta_pr
      return old_meta_pr if old_meta_pr.id? && old_meta_pr.done?

      meta_pr.children_removed = !old_meta_pr.close_stale_children!(meta_pr.children).empty?
    end
    with_flock(meta_pr.repository.name) do
      with_flock(meta_pr.slug) do
        meta_pr.refresh_all_repos!(load_templates = true)
        meta_pr.create_children!
        meta_pr.create_branch! # has to be before update_config_file
        meta_pr.refresh_children!
        meta_pr.update_config_file! # has to be before create so there is a commit
        meta_pr.create!
        meta_pr.write_children_state! # has to be after create because it requires the parent id
        meta_pr.write_own_state!

        # just update old repos, new ones will get correct state during creation
        old_meta_pr.set_draft_state!(meta_pr.draft?) if old_meta_pr.present? && old_meta_pr.id? && meta_pr.draft? != old_meta_pr.draft? 
      end
    end

    meta_pr.status_collection.statuses.each do |status|
      meta_pr.set_children_status!(status)
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
    return @meta_pr unless @meta_pr.nil?
    @meta_pr = MetaPullRequest.from_params(@meta_repo.merge(sub_repos: @sub_repos))
  end
end
