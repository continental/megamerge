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

class MergeMegaMerge
  include Callable

  def initialize(organization, repo, pull_id)
    @organization = organization
    @repo = repo
    @pull_id = pull_id
  end

  def call
    with_flock do
      meta_pr.merge_state!
    end
  end

  private

  def pull_request
    @pull_request ||= repository.pull_request(@pull_id) if PullRequest.id?(@pull_id)
  end

  def meta_pr
    @meta_pr ||= MetaPullRequest.from_pull_request(pull_request)
  end

  def repository
    @repository ||= Repository.new(organization: @organization, repository: @repo)
  end
end
