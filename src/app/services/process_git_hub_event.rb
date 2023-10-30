# frozen_string_literal: true

# Copyright (c) 2021 Continental Automotive GmbH
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

class ProcessGitHubEvent < BaseModel
  include Callable
  include Loggable

  def initialize(event, payload)
    @event = event
    @payload = payload[:webhook]
  end

  def call
    return if event.nil?

    RequestStore.store[:client] = GitHub::Bot.new(id: payload[:installation][:id], organization: nil)

    event_method = :"process_#{event}"
    if respond_to?(event_method, true)
      logger.info "process event #{event}"
      send(event_method) || ''
      
    else
      ''
    end

    # execute queued events if lock can be acquired 
    with_flock("event_worker", false) do
      event_queue = IpcStore.new("events")
      loop do
        events = event_queue.list

        break if events.empty?

        events.each do |event, name|
          org, repo, id = name.split("/")

          logger.info "#### ----- working on event _#{event}_ of #{name}"
          begin 
            start = Time.now

            if event.eql? "SyncPrsOnTargetChange"
              GitHubEvent::SyncPrsOnTargetChange.execute(org, repo, id)
            elsif event.eql? "MergeMegaMerge"
              GitHubEvent::MergeMegaMerge.execute(org, repo, id)
            elsif event.eql? "DeleteSourceBranches"
              GitHubEvent::DeleteSourceBranches.execute(org, repo, id)
            elsif event.eql? "SyncPrOnSourceChange"
              GitHubEvent::SyncPrOnSourceChange.execute(org, repo, id)
            else
              logger.info "unknown event _#{event}_ in #{name}"
            end
          rescue Exception => e
            logger.info e.message + e.backtrace.join("\n")
          end
          event_queue.delete(event, name)
          logger.info  "#### ----- END working on event _#{event}_ of #{name}, took #{Time.now - start} sec"

          
        end
      end
      
    end

  rescue StandardError => e
    logger.info e.message + e.backtrace.join("\n")
  end

  private

  attr_accessor :event, :payload

  def process_status
    try_merge_metas = GitHubEvent::HandleStatus.call(event, payload)
    add_event("MergeMegaMerge", try_merge_metas)
  end

  def process_pull_request_review
    # pull request approve -> merge if possible
    return unless payload[:review][:state] == 'approved'
    affected_metas = GitHubEvent::MergeMegaMerge.new(event, payload).affected_meta_pull_requests
    add_event("MergeMegaMerge", affected_metas)
  end

  def process_push
    affected_metas = GitHubEvent::SyncPrsOnTargetChange.new(event, payload).affected_meta_pull_requests
    add_event("SyncPrsOnTargetChange", affected_metas)
  end

  def process_pull_request
    # pull request closed && merged -> delete branch
    # will only work for MM PRs because MMState is nil for non-MM PRs
    logger.info "PR #{payload[:repository][:full_name]}/#{payload[:number]} was #{payload[:action]}"

    # clear PR cache if something changes
    Rails.cache.delete("PRs_#{payload[:repository][:full_name]}") if payload[:action].in?(['reopened', 'opened', 'closed'])

    if payload[:action] == 'closed' && payload[:pull_request][:merged]
      GitHubEvent::DeleteSourceBranches.call(event, payload)
      #affected_metas = GitHubEvent::DeleteSourceBranches.new(event, payload).affected_meta_pull_requests
      #add_event("DeleteSourceBranches", affected_metas)
    elsif payload[:action] == 'synchronize' && !is_own_event?
      # pull request update -> update default.xml
      affected_metas = GitHubEvent::SyncPrOnSourceChange.new(event, payload).affected_meta_pull_requests
      add_event("SyncPrOnSourceChange", affected_metas)
    end
  end

  def is_own_event?
    own_event = payload[:sender][:type] == 'Bot' && payload[:sender][:login].include?('megamerge')
    logger.info 'this event originates from myself and will not be handled!' if own_event
    own_event
  end

  
  def add_event(event, affected_metas)
    return if affected_metas.blank?
    event_queue = IpcStore.new("events")
    affected_metas.each do |meta_pr|
      logger.info "adding event _#{event}_ of #{meta_pr.slug} to queue"
      event_queue.add(event, meta_pr.slug)
    end
    #logger.info "items: #{event_queue.list} size: #{event_queue.size}"
  end


end
