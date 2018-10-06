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

class PullRequestSerializer < BaseModel
  include ActiveModel::Serializers::JSON

  attr_accessor :id, :organization, :repository
  attr_accessor :target, :source, :shadow, :merged, :megamerge, :sha
  attr_accessor :children

  def self.from_pull_request(pull)
    new(
      id: pull.id,
      organization: pull.repository.organization,
      repository: pull.repository.repository,
      target: pull.target_branch,
      source: pull.source_branch,
      shadow: pull.shadow_branch,
      merged: pull.merged?,
      sha: pull.merge_commit_sha,
      megamerge: pull.parent? || !pull.children&.empty?,
      children: pull.respond_to?(:children) ? pull.children&.map { |child| from_pull_request(child) } : nil
    )
  end

  def attributes
    {
      'id' => '',
      'organization' => '',
      'repository' => '',
      'target' => '',
      'source' => '',
      'shadow' => '',
      'merged' => '',
      'sha' => '',
      'megamerge' => '',
      'children' => ''
    }
  end
end
