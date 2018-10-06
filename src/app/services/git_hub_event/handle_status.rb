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
  class HandleStatus
    include Callable
    include Loggable

    def initialize(payload)
      @payload = payload
    end

    def call
      logger.info "Handle Status: #{status}"
      return if status.megamerge_status?

      logger.info "Possible branches: #{branches}"
      return if branches.empty? || parents.empty?

      logger.info "HandleStatus: #{parents.map(&:id)}"
      parents.each { |parent| parent.set_children_status!(status) }
      return 'Status set' unless status.success?

      logger.info "Attempt merge for: #{parents.map(&:slug)}"
      merge_parents!
    end

    private

    attr_accessor :payload

    def merge_parents!
      parents.each_with_object(+'') do |parent, log|
        if parent.merge_state!.nil?
          log << "Not megamergeable: #{parent.slug}"
          next
        end
        log << "doing finalmerge of #{parent.slug}"
      end
    end

    def status
      @status ||= PullRequest::PullRequestStatus.from_params(payload)
    end

    def repository
      @repository ||= Repository.from_name(payload[:repository][:full_name])
    end

    def pull_requests
      @pull_requests ||= repository.find_pull_requests_for_branches(branches, state: 'open')
    end

    def branches
      @branches ||= payload[:branches].select { |branch| branch[:commit][:sha] == payload[:sha] }
                                      .map { |branch| [branch[:name], branch[:commit][:sha]] }
                                      .to_h
    end

    def parents
      @parents ||= pull_requests.map { |pull| parent_pull_request(pull) }.compact
    end

    def parent_pull_request(pull)
      parent_body = MegaMerge::ParentDecoder.decode(pull[:body])
      child_body = MegaMerge::ChildDecoder.decode(pull[:body])
      return nil if parent_body.nil? && child_body.nil?
      return MetaPullRequest.from_pull_request(pull).refresh! if parent_body

      parent = MetaPullRequest.from_parent_decoding(child_body[:config]).refresh!
      parent.fill_from_decoded!(MegaMerge::ParentDecoder.decode(parent.body))
    end
  end
end
