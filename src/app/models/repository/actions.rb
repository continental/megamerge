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
        #logger.info client.to_yaml #added
        raise "PR #{name} ##{id} state is still unknown (retry?)" if pr[:mergeable_state] == 'unknown' && !pr[:merged] && pr[:state] != 'closed'
      rescue StandardError => e
        logger.info "waiting for PR to be ready.... ##{id}"
        sleep(0.5 * (11 - tries))
        retry unless (tries -= 1).zero?
        raise e
      end

      pr
    end

    def find_pull_requests_for_source_hash(source_hash, state: 'all')
      pull_requests(state: state).select do |pr|
        source_hash.include? pr[:head][:sha]
      end
    end

    def find_pull_requests_for_target_branches(branches, state: 'all')
      pull_requests(state: state).select do |pr|
        branches.include? pr[:base][:ref]
      end
    end

    def find_open_pr(source_repository, source_branch, target_branch)
      prs = pull_requests(state: 'open')
      pr = prs.find do |branch_data|
        branch_data[:head][:ref] == source_branch &&
          branch_data[:base][:ref] == target_branch &&
          branch_data[:head][:repo][:full_name] == source_repository.name
      end
      return if pr.nil?

      PullRequest.from_github_data(pull_request(pr[:number])) # replace by pr.refresh!   ?
    end

    #def merge_pr!(id, message: '', squash: false)
    #  logger.info "merging #{repository.name}/#{id} squash: #{squash}"
    #  if squash
    #    commits = pull_request_commits(id)
    #    final_commit_msg = message + "\n" + commits.map { |commit|
    #      commit[:commit][:message] unless commit[:commit][:message].start_with?(MetaPullRequest::MEGAMERGE_COMMIT_PREFIX)
    #    }.compact.uniq.join("\n")
    #
    #    merge_pull_request!(id, final_commit_msg, merge_method: 'squash')
    #  else
    #    merge_pull_request!(id, message, merge_method: 'merge')
    #  end
    #end

    def merge_pull_request!(id, message, merge_method: 'merge')
      tries ||= 3
      merge_pull_request(id, message, merge_method: merge_method)
    rescue Octokit::Error => e
      logger.info "error during merge ... retry ... #{e.message.split(' // ',2).first}"
      sleep(1)
      retry unless (tries -= 1).zero?
      raise e
    end

    def create_pull_request(base, head, title, body = nil, draft = false)
      PullRequest.from_github_data(client.create_pull_request(name, base, head, title, body, {:draft => draft}))
    end

    def pull_request_exists?(id)
      !!pull_request(id)
    rescue Octokit::NotFound
      false
    end

    def push_empty_commit!(branch, message)
      parent = commit(branch)
      new_commit = create_commit(message, parent.commit.tree.sha, parent.sha)
      update_branch(branch, new_commit.sha)
    end

    def create_branch!(new_branch, base_branch)
      hash = latest_sha(base_branch)
      create_ref!('heads/' + new_branch, hash)
    end

    def create_ref!(new_branch, base_hash)
      create_ref(new_branch, base_hash)
    rescue Octokit::UnprocessableEntity => e
      raise e unless e.message.include? 'Reference already exists'
    end

    def find_refs(name)
      begin
        refs = ref(name)
      rescue Octokit::NotFound => e
        return nil
      end
      refs.map{|ref| ref.ref['refs/'.length, 1024] }
    end


    def branch_exists?(branch_name)
      branches.any? do |branch|
        branch[:name] == branch_name
      end
    end

    def is_latest_or_parent?(branch, hash_to_find)
      commit = commit(branch)
      commit[:sha] == hash_to_find || commit[:parents].any? { |parent| parent[:sha] == hash_to_find }
    end

    def reset_branch_to_base_hash!(base_hash, branch_to_reset)
      update_branch(branch_to_reset, base_hash, true)
    end

    def latest_sha(branch_name)
      branch_data = branch(branch_name)
      return branch_data[:commit][:sha] if branch_data[:commit] && branch_data[:commit][:sha]

      0
    end

    def delete_branch!(branch)
      logger.info "deleting #{branch}"
      delete_branch(branch)
    # if delete fails because of branch protection just continue.
    rescue StandardError => e
      logger.warn "unable to delete branch #{branch} (#{e.message})"
    end

    def compare_branches(base, head)
      compare(base, head)
    rescue Octokit::Error => e
      logger.warn("compare_branches(#{base}, #{head}: #{e.message}")
      # Return a big number
      { ahead_by: 999, behind_by: 999 }
    end

    def branch_ahead?(base, head)
      return false if base == head

      compare_branches(base, head)[:ahead_by].positive?
    end

    def branch_behind?(base, head)
      return false if base == head

      compare_branches(base, head)[:behind_by].positive?
    end

  end
end
