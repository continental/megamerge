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

class ProcessGitHubEvent
  include Callable
  include Loggable

  def initialize(event, payload)
    @event = event
    @payload = payload[:webhook]
  end

  def call
    return if event.nil?
    logger.info "process event #{event}"

    event_method = :"process_#{event}"
    if respond_to?(event_method, true)
      with_flock do
        send(event_method) || ''
      end
    else
      ''
    end
  rescue StandardError => e
    e.message + e.backtrace.to_s + "\n"
  end

  private

  attr_accessor :event, :payload

  def process_status
    GitHubEvent::HandleStatus.call(payload)
  end

  def process_pull_request_review
    # pull request approve -> merge if possible
    GitHubEvent::MergeMegaMerge.call(payload) if payload[:review][:state] == 'approved'
  end

  def process_push
    GitHubEvent::FindAndSyncMetaShadowBranch.call(payload)
  end

  def process_pull_request
    # pull request closed && merged -> delete branch
    # will only work for MM PRs because MMState is nil for non-MM PRs
    if payload[:action] == 'closed' &&
       payload[:pull_request][:merged]
      GitHubEvent::DeleteSourceBranches.call(payload)
    elsif payload[:action] == 'synchronize'
      # pull request update -> update default.xml
      GitHubEvent::SyncMetaShadowBranch.call(payload)
    end
  end
end
