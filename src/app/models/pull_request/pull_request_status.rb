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
  # Represents a single PR status
  class PullRequestStatus < BaseModel
    MM_STATUS_PREFIX = 'megamerge/'

    def self.from_github_data(status)
      new(
        id: status[:id],
        state: status[:state],
        description: status[:description],
        target_url: status[:target_url],
        context: status[:context],
        name: status[:name]
      )
    end

    attr_accessor :id, :state, :description, :target_url, :context, :name

    def success?
      state == 'success'
    end

    def megamerge_status?
      context&.starts_with?(MM_STATUS_PREFIX)
    end

    def create_with_prefix!(repository, sha)
      logger.info "creating status #{MM_STATUS_PREFIX + context} on #{sha} (#{state})"
      repository.create_status(
        sha, state,
        context: MM_STATUS_PREFIX + context,
        target_url: target_url,
        description: description
      )
    end

    def create!(repository, sha)
      logger.info "creating status #{context} on #{sha} (#{state})"
      repository.create_status(
        sha, state,
        context: context,
        target_url: target_url,
        description: description
      )
    end
  end
end
