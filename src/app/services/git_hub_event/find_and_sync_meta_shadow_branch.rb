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
  class FindAndSyncMetaShadowBranch
    include Callable
    include Loggable

    def initialize(payload)
      @payload = payload
    end

    def call
      logger.info "FindAndSyncMetaShadowBranch: #{branch_name}"
      return 'Push on shadow branch' if on_shadow_branch?
      return "No open pull requests for #{branch_name} in #{repo.name}" if meta_pulls.empty?
      meta_pulls.each(&:update_state!)

      "Updated pull requests: #{meta_pulls.map(&:id).join(', ')}"
    end

    private

    attr_accessor :payload

    def meta_pulls
      @meta_pulls ||= pulls.map { |pull| MetaPullRequest.from_pull_request(pull) }.compact
    end

    def pulls
      return [] if branches.empty?
      @pulls ||= repo.find_pull_requests_for_branches(branches, state: 'open')
    end

    def branches
      return {} if branch.nil?
      @branches ||= [[branch[:name], branch[:commit][:sha]]].to_h
    end

    def branch
      @branch ||= repo.branch(branch_name)
    rescue Octokit::NotFound
      @branch ||= nil
    end

    def branch_name
      @branch_name ||= payload[:ref].sub('refs/heads/', '') + MetaPullRequest::SHADOW_BRANCH_SUFFIX
    end

    def on_shadow_branch?
      payload[:ref].ends_with?(MetaPullRequest::SHADOW_BRANCH_SUFFIX)
    end

    def repo
      @repo ||= Repository.from_name(payload[:repository][:full_name])
    end
  end
end
