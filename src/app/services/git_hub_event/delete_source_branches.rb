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

module GitHubEvent
  class DeleteSourceBranches < EventProcessor

    def call
      if parent_body(payload[:pull_request]).present? || child_body(payload[:pull_request]).present?
          repo.delete_branch!(source_branch)
          repo.find_refs("mm/#{id}/")&.each{ |branch| repo.delete_ref(branch) } # delete temp branches
      end
    end
      
    def self.execute(org, repo, id)
     # meta_pr_slug = org+'/'+repo+'/'+id
     # # TODO: DELTE IMMEDIATELLY
     # logger.info "deleting source branches from: #{meta_pr_slug}"
     # with_flock(meta_pr_slug) do
     #   meta_pr = MetaPullRequest.load(org,repo,id)
     #   meta_pr.delete_source_branches!
     # end

    end

    def id
      payload[:number]
    end

    def source_branch
      payload[:pull_request][:head][:ref]
    end

  end
end
