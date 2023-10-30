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
  # Represents the a combined pull request status
  class PullRequestStatuses < BaseModel
    def self.from_github_data(pr_statuses)
      new(
        sha: pr_statuses[:sha],
        total_count: pr_statuses[:total_count],
        statuses: pr_statuses[:statuses].map { |status| parent::PullRequestStatus.from_github_data(status) },
        state: pr_statuses[:state],
      )
    end

    attr_accessor :sha, :total_count, :statuses, :state, :required_contexts

    def missing_checks(required_checks)
      @missing_checks||= required_checks.filter_map do |check|
        stat = statuses.find { |status| (status.context.include? check)}
        next PullRequestStatus.new({:context=> check, :target_url => ""}) if stat.nil?
        next if stat.success?
        stat
      end
    end

  end
end
