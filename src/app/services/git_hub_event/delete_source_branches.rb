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
  class DeleteSourceBranches
    include Callable
    include Loggable

    def initialize(payload)
      @payload = payload
    end

    def call
      logger.info "DeleteSourceBranches: #{pull_request&.id}"
      return 'Not a MM PR' unless parent_body || child_body
      pull_request.delete_branches!
      "deleting source branches of PR #{payload[:number]} in #{payload[:repository][:full_name]}\n"
    end

    private

    attr_accessor :payload

    def pull_request_body
      payload[:pull_request][:body]
    end

    def parent_body
      @parent_body ||= MegaMerge::ParentDecoder.decode(pull_request_body)
    end

    def child_body
      @child_body ||= MegaMerge::ChildDecoder.decode(pull_request_body)
    end

    def pull_request
      @pull_request ||= MetaPullRequest.from_pull_request(payload[:pull_request]) ||
                        PullRequest.from_github_data(payload[:pull_request])
    end
  end
end
