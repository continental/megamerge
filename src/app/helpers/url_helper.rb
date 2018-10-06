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

module UrlHelper
  DEFAULT_GITHUB_BASE_URL = Rails.application.config.url

  def self.included(base)
    return if base.const_defined?(:GITHUB_BASE_URL)
    base.const_set :GITHUB_BASE_URL, UrlHelper::DEFAULT_GITHUB_BASE_URL
  end

  def github_base_url
    self.class.const_get(:GITHUB_BASE_URL)
  end

  def pr_url(organization, repository, pull_id)
    "#{github_base_url}/#{organization}/#{repository}/pull/#{pull_id}"
  end

  def repo_url(organization, repository)
    "#{github_base_url}/#{organization}/#{repository}"
  end

  def branch_url(organization, repository, branch)
    "#{github_base_url}/#{organization}/#{repository}/tree/#{branch}"
  end

  def commit_url(organization, repository, branch)
    "#{github_base_url}/#{organization}/#{repository}/commit/#{branch}"
  end
end
