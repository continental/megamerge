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

class Repository
  # Helper methods for dealing with repositories
  module Actions
    def pull_request(id)
      id = id.to_i
      return if id.zero?

      # A pull request will have unknown state until github
      # has checked for mergeability
      begin
        tries ||= 10
        pr = client.pull_request(name, id)
        raise if pr[:mergeable_state] == 'unknown' && !pr[:merged]
      rescue StandardError
        logger.info "waiting for PR to be ready.... ##{pr[:number]} #{pr[:mergeable_state]}"
        sleep(0.5)
        retry unless (tries -= 1).zero?
      end

      pr
    end

    def find_pull_requests_for_branches(branches, state: 'all')
      pull_requests(state: state).select do |pr|
        branches[pr[:head][:ref]] == pr[:head][:sha]
      end
    end

    def find_open_pr(source_branch, target_branch)
      prs = pull_requests(state: 'open')
      pr = prs.find do |branch_data|
        branch_data[:head][:ref] == source_branch && branch_data[:base][:ref] == target_branch
      end
      return if pr.nil?
      PullRequest.from_github_data(pull_request(pr[:number]))
    end

    def merge_pr!(id, message: '', squash: false)
      if squash
        commits = pull_request_commits(id)
        final_commit_msg = commits.inject(message) do |res, commit|
          res + "#{commit[:commit][:message]}\n"
        end
        merge_pull_request(id, final_commit_msg, merge_method: 'squash')
      else
        merge_pull_request(id, message, merge_method: 'merge')
      end
    end

    def create_pull_request(base, head, title)
      PullRequest.from_github_data(client.create_pull_request(name, base, head, title))
    end

    def pull_request_exists?(id)
      !!pull_request(id)
    rescue Octokit::NotFound
      false
    end

    def create_branch!(new_branch, base_branch)
      hash = latest_sha(base_branch)
      begin
        create_ref('heads/' + new_branch, hash)
      rescue Octokit::UnprocessableEntity => e
        raise Octokit::UnprocessableEntity unless e.message.include? 'Reference already exists'
      end
    end

    def branch_exists?(branch_name)
      branches.any? do |branch|
        branch[:name] == branch_name
      end
    end

    def reset_branch_to_base!(base, branch_to_reset)
      update_branch(branch_to_reset, latest_sha(base), true)
    end

    def latest_sha(branch_name)
      branch_data = branch(branch_name)
      return branch_data[:commit][:sha] if branch_data[:commit] && branch_data[:commit][:sha]
      0
    end

    def compare_branches(base, head)
      base_sha = latest_sha(base)
      head_sha = latest_sha(head)
      compare(base_sha, head_sha)
    rescue Octokit::Error => e
      logger.warn("compare_branches(#{base}, #{head}: #{e.message}")
      # Return a big number
      { ahead_by: 999, behind_by: 999 }
    end

    def branch_ahead?(base, head)
      return false if base == head
      compare_branches(base, head)[:ahead_by].positive?
    end

    def branches_identical?(base, head)
      base_sha = latest_sha(base)
      head_sha = latest_sha(head)
      base_sha == head_sha &&
        !branch_ahead?(base, head)
    end

    def module_manifest_filenames(ref)
      filenames(ref).reject do |name|
        name.match(/^\.gitmodules$|.*\.xml$/).nil?
      end
    end

    def filenames(ref)
      contents(ref: ref).map { |file| file[:name] }
    end
  end
end
