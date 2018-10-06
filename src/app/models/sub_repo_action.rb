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

class SubRepoAction < BaseModel
  ADD = 1
  UPDATE_BY_HASH = 0
  UPDATE_BY_BRANCH = 2
  REMOVE = 3

  def self.from_params_list(params)
    sub_repos = params&.map { |change| from_params(change) }&.compact
    return {} if sub_repos.nil?
    Hash[sub_repos.collect { |v| [v.name, v] }]
  end

  def self.from_pr_list(prs)
    sub_repos = prs&.map { |pr| from_pr(pr) }&.compact
    return {} if sub_repos.nil?
    Hash[sub_repos.collect { |v| [v.name, v] }]
  end

  def self.from_pr(pull)
    new(
      action: UPDATE_BY_BRANCH,
      organization: pull.repository.organization,
      repository: pull.repository.repository,
      ref: pull.source_branch
    )
  end

  def self.from_pr_list(prs)
    sub_repos = prs&.map { |pr| from_pr(pr) }&.compact
    return {} if sub_repos.nil?
    Hash[sub_repos.collect { |v| [v.name, v] }]
  end

  def self.from_pr(pull)
    new(
      action: UPDATE_BY_BRANCH,
      organization: pull.repository.organization,
      repository: pull.repository.repository,
      ref: pull.source_branch,
      sha: pull.merge_commit_sha
    )
  end

  attr_writer :organization, :repository, :settings, :ref, :done, :sha

  def action
    @action || UPDATE_BY_BRANCH
  end

  def action=(value)
    @action = value.to_i
  end

  def name
    "#{organization}/#{repository}"
  end

  def organization
    @organization || ''
  end

  def repository
    @repository || ''
  end

  def ref
    @ref || @sha || ''
  end

  def sha
    @sha || @ref || ''
  end

  def done?
    @done || (action == UPDATE_BY_BRANCH)
  end
  alias done done?

  def done!
    @done = true
  end

  def to_xml(doc, remote: nil)
    node = Nokogiri::XML::Node.new('project', doc)
    node[:groups] = ''
    node[:name] = repository
    node[:path] = ''
    node[:remote] = remote
    node[:revision] = ref
    node[:target_branch] = 'master'
    node
  end
end
