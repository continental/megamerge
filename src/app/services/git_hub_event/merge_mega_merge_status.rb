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
  class MergeMegaMergeStatus
    include Callable
    include Loggable

    def initialize(payload)
      @payload = payload
    end

    def call
      logger.info "MergeMegaMergeStatus: #{merge_candidates.map(&:id)}"
      return 'No merge candidates' if merge_candidates.empty?

      merge_candidates.each_with_object(+'') do |candidate, log|
        if candidate.merge_state!.nil?
          log << "Not megamergeable: #{candidate.slug}"
          next
        end
        log << "doing finalmerge of #{candidate.slug}"
      end
    end

    private

    attr_accessor :payload

    def merge_candidates
      @merge_candidates ||= pull_requests.map { |pull| parent_pull_request(pull) }.compact
    end

    def parent_pull_request(pull)
      parent_body = MegaMerge::ParentDecoder.decode(pull[:body])
      child_body = MegaMerge::ChildDecoder.decode(pull[:body])
      return nil if parent_body.nil? && child_body.nil?
      return MetaPullRequest.from_pull_request(pull).refresh! if parent_body

      parent = MetaPullRequest.from_parent_decoding(child_body[:config]).refresh!
      parent.fill_from_decoded!(MegaMerge::ParentDecoder.decode(parent.body))
    end

    def pull_requests
      @pull_requests ||= repository.find_pull_requests_for_branches(branches, state: 'open')
    end

    def branches
      @branches ||= payload[:branches].map do |branch|
        [branch[:name], branch[:commit][:sha]]
      end.to_h
    end

    def repository
      @repository ||= Repository.from_name(payload[:repository][:full_name])
    end
  end
end
