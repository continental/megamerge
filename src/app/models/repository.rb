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

require_dependency 'git_hub/bot'

# Responsible for all interactions with the repositories on GitHub itself.
# Acts as a proxy to the octokit Object. All actions defined by octokit can be
# called directly on the repository, but with the name ommitted
#   Example: octokit.pull_requests('org/repo') -> repository.pull_requests
#
# Some of the octokit actions have been overwritten. See repository/actions.rb for details.
#
# By default the repository will interact with github as the BotUser
class Repository < BaseModel
  extend Repository::GitHubUrlParser
  include Repository::Actions

  def self.from_name(name)
    org, repo = name.split('/')
    new(
      organization: org,
      repository: repo
    )
  end

  attr_accessor :organization, :repository

  validates! :organization, presence: true
  validates! :repository, presence: true

  def self.name(organization, repository)
    "#{organization}/#{repository}"
  end

  def ==(other)
    !other.nil? && other.organization == organization && other.repository == repository
  end

  def name
    self.class.name(organization, repository)
  end

  def default_branch
    @default_branch ||= repo[:default_branch]
  end

  # branches gets called often. Caching this saves a lot of requests
  def branches
    @branches ||= client.branches(name)
  end

  def branch_protection(branch)
    @branch_protection ||= {}
    @branch_protection[branch] ||= client.branch_protection(name, branch)
  end

  def method_missing(mid, *args, &block)
    if args.empty?
      client.send(mid, name, &block)
    else
      client.send(mid, name, *args, &block)
    end
  end

  def respond_to_missing?(mid, priv)
    client.respond_to?(mid, priv)
  end

  def as_client(github_client)
    old_client = client
    @client = github_client
    res = yield(self)
    @client = old_client
    res
  end

  private

  def client
    @client ||= GitHub::Bot.from_organization(organization)
  end
end
