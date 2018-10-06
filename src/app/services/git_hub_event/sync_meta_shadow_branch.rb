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
  class SyncMetaShadowBranch
    include Callable
    include Loggable

    def initialize(payload)
      @payload = payload
    end

    def call
      logger.info "SyncMetaShadowBranch: #{parent_pull_request&.id}"
      return 'Not a mega merge pull request' if parent_pull_request.nil?
      return 'Up to date' unless parent_pull_request.outdated? ||
                                 parent_pull_request.children_outdated?

      latest_commit = parent_pull_request.update_state!

      %W[
        updating branch #{parent_pull_request.repository.name}:
        #{parent_pull_request.source_branch} -> #{parent_pull_request.shadow_branch},
        new commit is #{latest_commit}\n
      ].join(' ')
    end

    private

    attr_accessor :payload

    def parent_pull_request
      return nil if parent_body.nil? && child_body.nil?
      return @parent_pull_request ||= MetaPullRequest.new(id: payload[:number], repository: repository).refresh! if parent_body
      parent = MetaPullRequest.from_parent_decoding(child_body[:config]).refresh!
      @parent_pull_request ||= parent.fill_from_decoded!(MegaMerge::ParentDecoder.decode(parent.body))
    end

    def parent_body
      @parent_body ||= MegaMerge::ParentDecoder.decode(pull_request_body)
    end

    def child_body
      @child_body ||= MegaMerge::ChildDecoder.decode(pull_request_body)
    end

    def pull_request_body
      payload[:pull_request][:body]
    end

    def repository
      @repository ||= Repository.from_name(payload[:repository][:full_name])
    end
  end
end
