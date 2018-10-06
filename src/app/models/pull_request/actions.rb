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

class PullRequest
  module Actions
    def find_id
      pr = repository.find_open_pr(shadow_branch, target_branch)
      @id = 0 if pr.nil?
      merge_instance!(pr)
    end

    def wrong_id?
      return true unless id?
      pr = self.class.from_github_data(repository.pull_request(id))
      source_branch != pr.source_branch || target_branch != pr.target_branch
    end

    def stale?(new_pr)
      new_pr.nil? ||
        source_branch != new_pr.source_branch ||
        target_branch != new_pr.target_branch
    end

    def contains_commit?(sha)
      return false unless id?
      repository.pull_request_commits(id).any? { |commit| commit[:sha] == sha }
    end

    def create_branch!(source, target)
      repository.create_branch!(source, target)
    end

    def create!(heading: nil)
      return id if id?
      merge_instance!(repository.create_pull_request(target_branch, shadow_branch, heading || title))
      id
    end

    def create_as_user!(user, heading: nil)
      return id if id?
      merge_instance!(repository.as_client(user) do |repo|
        repo.create_pull_request(target_branch, shadow_branch, heading || title)
      end)
      id
    end

    def update!(heading: nil, content: nil)
      repository.update_pull_request(id, body: content || body, title: heading || title)
    end

    def merge!
      repository.merge_pr!(id)
    end

    def refresh!
      merge_instance!(self.class.from_github_data(repository.pull_request(id)))
    end

    def create_branches!
      create_branch!(shadow_branch, target_branch) unless shadow_branch_exists?
      create_branch!(source_branch, shadow_branch) unless source_branch_exists?
    end

    def close!
      return unless exists?
      repository.update_pull_request(id, state: 'closed')
    end

    def open!
      return unless exists?
      repository.update_pull_request(id, state: 'open')
    end

    def create_status!(status)
      status.create!(repository, source_branch_sha)
    end

    def delete_branch!(branch)
      return unless repository.branch_exists?(branch)
      repository.delete_branch(branch)
    # if delete fails because of branch protection just continue.
    rescue StandardError => e
      e.message + e.backtrace.to_s + "\n"
    end

    def delete_branches!
      delete_branch!(shadow_branch) if shadow_branch != source_branch
      delete_branch!(source_branch)
    end

    def overwrite_branch_protection!(commit_hash)
      # HACK: If branch protection is enabled and status checks are required,
      # then they are bypassed by quickly sending success states before the
      # CI can answer.
      protection = repository.branch_protection(target_branch)
      return unless protection[:required_status_checks] &&
                    protection[:required_status_checks][:contexts]

      state = 'success'
      protection[:required_status_checks][:contexts].each do |context|
        repository.create_status(commit_hash, state,
                                 state: state,
                                 description: 'MEGAMERGE',
                                 context: context)
      end
    rescue Octokit::NotFound
      logger.warn(
        "Failed to overwrite branch protection: Insufficient permissions for #{repository.name}"
      )
    end
  end
end
