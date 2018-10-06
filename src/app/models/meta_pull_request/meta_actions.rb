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

class MetaPullRequest
  module MetaActions
    def create!
      return id if id?
      # Need to preserve the original source branch as it's
      # overwritten by the shadow branch when the results are returned
      # from github
      original_source = source_branch
      merge_instance!(repository.create_pull_request(target_branch, shadow_branch, title))
      @source_branch = original_source
      id
    end

    def create_as_user!(user)
      return id if id?
      # Need to preserve the original source branch as it's
      # overwritten by the shadow branch when the results are returned
      # from github
      original_source = source_branch
      merge_instance!(repository.as_client(user) do |repo|
        repo.create_pull_request(target_branch, shadow_branch, title)
      end)
      @source_branch = original_source
      id
    end

    def refresh!
      original_source = source_branch
      merge_instance!(self.class.from_github_data(repository.pull_request(id)))
      @source_branch = original_source
      self
    end

    def merge!
      repository.merge_pr!(id, message: title, squash: squash?)
    end

    def close_stale_children!(new_children)
      children.each do |child|
        new_pr = new_children.find { |new_child| child.repository == new_child.repository }
        next unless child.stale?(new_pr)
        child.close!
      end
    end

    def create_children!
      children.each { |child| child.create!(heading: child.title || title) }
    end

    def create_children_as_user!(user)
      children.each { |child| child.create_as_user!(user, heading: child.title || title) }
    end

    def refresh_children!
      @children = children.map(&:refresh!)
    end

    def update_state!(sync: true)
      create_branches!
      # if the real branch is ahead we will have to force push since
      # force push removes commits that might be there, we can not do this if its a final merge
      if sync && repository.branch_ahead?(shadow_branch, source_branch)
        repository.reset_branch_to_base!(source_branch, shadow_branch)
      end

      refresh_children!
      write_file!
    end

    def write_file!
      latest_commit = file.write!(shadow_branch, child_actions, force_commit: !id?)
      return if latest_commit.nil?
      wait_for_commit(latest_commit) if id?
      latest_commit
    end

    # Hack around GitHub Bug: need to wait until the last commit is visible inside the PR
    def wait_for_commit(commit)
      tries ||= 25
      raise unless contains_commit?(commit)
    rescue StandardError
      sleep(0.5)
      logger.info "Waiting for #{commit}"
      retry unless (tries -= 1).zero?
    end

    def write_state!
      content = MegaMerge::ParentEncoder.encode(self)
      update!(content: content)
      update_children!
    end

    def update_children!
      children.each do |child|
        decoded = MegaMerge::ChildDecoder.decode(child.body)
        child.body = decoded&.[](:body) || child.body
        content = MegaMerge::ChildEncoder.encode(child)
        child.update!(content: content, heading: title)
      end
    end

    def merge_state!
      return unless megamergeable? &&
                    !children_outdated? &&
                    !outdated?

      children.each(&:merge!)
      latest_commit = update_state!(sync: false)
      overwrite_branch_protection!(latest_commit) unless latest_commit.nil?
      merge!
    end

    def close_state!
      close!
      children.each(&:close!)
    end

    def open_state!
      open!
      children.each(&:open!)
    end

    def delete_source_branches!
      return unless done?
      children.each(&:delete_branches!)
      delete_branches!
    end

    def find_target_repositories(target_branch)
      repos = target_file.projects.keys.map { |repo_name| Repository.from_name(repo_name) }
      repos.select do |repo|
        repo.branches.any? { |branch| branch[:name].eql?(target_branch) }
      end
    end

    def set_children_status!(status)
      children.each { |child| child.create_status!(status) }
    end
  end
end
