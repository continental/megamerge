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

module Api
  class ParentPull
    include Callable

    def initialize(org, repo, pull_id)
      @org = org
      @repo = repo
      @pull_id = pull_id
    end

    def call
      parent_pull_request || PullRequest.from_github_data(pull_request)
    end

    private

    attr_accessor :org, :repo, :pull_id

    def parent_pull_request
      return nil if parent_body.nil? && child_body.nil?
      return @parent_pull_request ||= MetaPullRequest.from_pull_request(pull_request) if parent_body
      parent = MetaPullRequest.from_parent_decoding(child_body[:config]).refresh!
      @parent_pull_request ||= parent.fill_from_decoded!(MegaMerge::ParentDecoder.decode(parent.body))
    end

    def pull_request
      @pull_request ||= repository.pull_request(pull_id) if PullRequest.id?(pull_id)
    end

    def parent_body
      @parent_body ||= MegaMerge::ParentDecoder.decode(pull_request&.body)
    end

    def child_body
      @child_body ||= MegaMerge::ChildDecoder.decode(pull_request&.body)
    end

    def repository
      @repository ||= Repository.new(organization: org, repository: repo)
    end
  end
end
