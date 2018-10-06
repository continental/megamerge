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

# Represents the pull request github pull requests. By default
# this will be populated as a `Child pull request`.
# All state in relation to a mega merge pull request should be put here.
# The actions performed by a pull request can be found under `pull_request/actions.rb`
class PullRequest < BaseModel
  include PullRequest::Actions

  def self.from_params(params)
    new(keep_attributes(params)
      .merge(
        id: params[:pull_id],
        repository: Repository.from_params(params)
      ))
  end

  def self.from_github_data(data)
    new(
      id: data[:number],
      repository: Repository.from_name(data[:head][:repo][:full_name]),
      title: data[:title],
      body: data[:body],
      source_branch: data[:head][:ref],
      source_branch_sha: data[:head][:sha],
      target_branch: data[:base][:ref],
      mergeable: data[:mergeable],
      merged: data[:merged],
      mergeable_state: data[:mergeable_state],
      merge_commit_sha: data[:merge_commit_sha],
      state: data[:state]
    )
  end

  def self.from_child_decoding(decoded, parent)
    pr = new(
      id: decoded[:id],
      repository: Repository.from_name(decoded[:name]),
      parent: parent
    ).refresh!
    pr.body = decoded[:body]
    pr
  end

  attr_writer :target_branch, :source_branch, :shadow_branch
  attr_accessor :parent
  attr_accessor :repository, :title, :body, :merge_commit_sha, :source_branch_sha
  attr_accessor :merged, :mergeable, :mergeable_state, :state

  attribute_method_suffix '?'
  define_attribute_methods :mergeable, :squash, :merged, :removeable, :parent

  validates! :repository, presence: true
  validates :id, pull_request_number: true

  def id
    @id || 0
  end

  def id=(value)
    @id = value.to_i.positive? ? value.to_i : 0
  end

  def self.id?(value)
    value.present? && value.to_i.positive?
  end

  def id?
    self.class.id?(id)
  end

  def exists?
    id? && repository.pull_request_exists?(id)
  end

  def target_branch
    @target_branch || repository.default_branch
  end

  def removeable
    @removeable || false
  end

  def removeable=(value)
    @removeable = (value.is_a?(String) && value == 'true') || (!!value == value && value)
  end

  def squash
    @squash.bool? ? @squash : true
  end

  def squash=(value)
    @squash = if value.bool?
                value
              elsif value.is_a? String
                value != 'false'
              else
                true
              end
  end

  def status
    if id?
      @status ||= existing_status
    elsif shadow_branch_exists? && !branch_has_mergeable_commits?
      @status ||= { text: 'Source and Target are the same', color: 'danger' }
    else
      @status ||= { text: 'OK', color: 'muted' }
    end
  end

  def source_branch
    @source_branch.presence || repository.default_branch
  end

  def shadow_branch
    @shadow_branch.presence || source_branch
  end

  def source_branch_exists?
    @source_branch_exists ||= repository.branch_exists?(source_branch)
  end

  def shadow_branch_exists?
    @shadow_branch_exists ||= repository.branch_exists?(shadow_branch)
  end

  def branch_has_mergeable_commits?
    repository.branch_ahead?(target_branch, shadow_branch)
  end

  def branches_identical?
    repository.branches_identical?(shadow_branch, target_branch)
  end

  def outdated?
    @outdated ||= !closed? &&
                  source_branch_exists? &&
                  shadow_branch_exists? &&
                  repository.branch_ahead?(shadow_branch, source_branch)
  end

  def slug(delim: '/')
    "#{repository.name}#{delim}#{id}"
  end

  def md_link
    "[#{slug(delim: '#')}](#{Rails.application.config.github[:server]}/#{slug(delim: '/pull/')})"
  end

  def self.branch_slug(repo, source, target)
    sb = ERB::Util.url_encode(source)
    tb = ERB::Util.url_encode(target)
    "#{repo.name}/#{sb}/#{tb}"
  end

  def branch_slug
    self.class.branch_slug(repository, source_branch, target_branch)
  end

  def state_unknown?
    mergeable_state == 'unknown'
  end

  def blocked?
    mergeable_state == 'blocked'
  end

  def dirty?
    mergeable_state == 'dirty'
  end

  def closed?
    state == 'closed'
  end

  def saveable?
    status[:text] != 'Source and Target are the same'
  end

  def megamergeable?
    mergeable? && !blocked? && !dirty? && !closed?
  end

  def pr_statuses
    @pr_statuses ||= PullRequestStatuses.from_github_data(repository.combined_status(source_branch_sha), repository.branch_protection(target_branch))
  end

  def pr_reviews
    @pr_reviews ||= PullRequestReviews.from_github_data(repository.pull_request_reviews(id))
  end

  private

  def existing_status
    if merged?
      { text: 'Merged', color: 'success' }
    elsif closed?
      { text: 'Closed', color: 'danger' }
    elsif !mergeable? && dirty?
      { text: 'Merge conflicts', color: 'danger' }
    elsif mergeable? && blocked?
      if pr_statuses.blocking?
        {
          text: 'Waiting for checks',
          color: 'warning',
          checks: pr_statuses.statuses.map { |status| { context: status.context, target_url: status.target_url } }
        }
      elsif repository.branch_protection(target_branch)[:required_pull_request_reviews]
        { text: 'Waiting for review', color: 'warning' }
      else
        { text: 'Unknown blocking reason', color: 'muted'}
      end
    elsif mergeable?
      { text: 'Mergeable', color: 'info' }
    else
      { text: 'Unknown', color: 'danger' }
    end
  end

  def attribute?(attribute)
    !!send(attribute)
  end
end
