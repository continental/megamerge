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
      pr = repository.find_open_pr(source_repository, shadow_branch, target_branch)
      @id = 0 if pr.nil?
      merge_instance!(pr)
    end

    def wrong_id?
      return true unless id?

      pr = self.class.from_github_data(repository.pull_request(id))
      source_branch != pr.source_branch || target_branch != pr.target_branch || source_repository.name != pr.source_repository.name
    end

    def stale?(new_pr)
      new_pr.nil? ||
        source_branch != new_pr.source_branch ||
        target_branch != new_pr.target_branch
    end

    # this one should not use any cache!!
    def contains_commit?(sha)
      return false unless id?

      repository.pull_request_commits(id).any? { |commit| commit[:sha] == sha }
    end

    def new_pr_body()
      self.body.nil? ? repository.default_template : self.body 
    end

    def create!(heading, draft)
      return id if id?
      create_return = repository.create_pull_request(target_branch, source_repository.organization + ":" + shadow_branch, heading || title, new_pr_body(), draft)
      @id = create_return.id

    end

    def update!(heading: nil, content: nil)
      repository.update_pull_request(id, body: content || body, title: heading || title)
    end

    #def merge!
    #  return if merged?
    #  repository.merge_pr!(id, message: title, squash: squash?)
    #end

    def refresh!
      merge_instance!(self.class.from_github_data(repository.pull_request(id)))
    end

    def close!
      return unless exists?

      repository.update_pull_request(id, state: 'closed')
    end

    def open!
      return unless exists?

      repository.update_pull_request(id, state: 'open')
    end

    def create_gql_merge_mutation
      return if merged?
      logger.info "merging #{repository.name}/#{id} merge method: #{@merge_method}"
      raise "No merge method selected for #{repository.name}/#{id}" if @merge_method.blank?

      merge_action = @merge_method

      hash = "h_#{simple_name}" + SecureRandom.alphanumeric(10)
      "
      #{hash}: mergePullRequest(input: {
        pullRequestId: \"#{object_id}\", 
        mergeMethod: #{merge_action}, 
      }) 
      {
        pullRequest {
          mergeCommit {
            oid
          }
          potentialMergeCommit {
            oid
          }
          merged
        }
        clientMutationId
      }
      "

    end

    def create_gql_close_mutation
      hash = "h_#{simple_name}" + SecureRandom.alphanumeric(10)
      "
      #{hash}: closePullRequest(input:{pullRequestId: \"#{object_id}\"}) {
        clientMutationId
      }
      "
    end
  
    def create_gql_open_mutation
      hash = "h_#{simple_name}" +SecureRandom.alphanumeric(10)
      "
      #{hash}: reopenPullRequest(input:{pullRequestId: \"#{object_id}\"}) {
        clientMutationId
      }
      "
    end

    def create_status!(status)
      status.create_with_prefix!(repository, source_branch_sha)
    end

    def delete_source_branch!
      source_repository.delete_branch!(source_branch)
    end

  end
end
