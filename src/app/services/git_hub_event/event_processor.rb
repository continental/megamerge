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
  class EventProcessor
    include Callable
    include Loggable

    def initialize(event, payload)
      @event = event
      @payload = payload
    end

    attr_accessor :payload, :event


    def affected_meta_pull_requests
      @affected_meta_pull_requests ||= pulls.map { |pull| meta_pull_request(pull) }.compact
    end

    def meta_pull_request(pull_request)
      return MetaPullRequest.from_pull_request(pull_request) unless parent_body(pull_request).nil?
      temp_child_body = child_body(pull_request)
      return MetaPullRequest.from_parent_decoding(temp_child_body[:config]) unless temp_child_body.nil?
    end

    def parent_body(pull_request)
      MegaMerge::ParentDecoder.decode(pull_request[:body])
    end

    def child_body(pull_request)
      MegaMerge::ChildDecoder.decode(pull_request[:body])
    end

    def repo
      @repo ||= Repository.from_name(payload[:repository][:full_name])
    end

  end
end
