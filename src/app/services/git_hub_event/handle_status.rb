# frozen_string_literal: true

# Copyright (c) 2021 Continental Automotive GmbH
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
module GitHubEvent
  class HandleStatus < EventProcessor

    def call
      # Discard our own status, unless it was successful
      return if status.megamerge_status?
      logger.info "New status update in #{status.name} to #{status.state}"

      ret = affected_meta_pull_requests.map do |meta_pr|
        if meta_pr.source_branch_sha.eql? updated_sha # just propagate if status is from meta
          with_flock(meta_pr.slug) do
            # propagate status to children
            meta_pr.refresh!
            meta_pr.set_children_status!(status)
          end
        end

        next nil if meta_pr.draft?
        next nil unless status.success?
        
        meta_pr
      end

      ret.compact
    end


    private

    def pulls
      return repo.find_pull_requests_for_source_hash(updated_sha, state: 'open')
    end

    def updated_sha
      payload[:commit][:sha]
    end

    def status
      @status ||= PullRequest::PullRequestStatus.from_params(payload)
    end

  end
end
