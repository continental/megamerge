# frozen_string_literal: true

# Copyright (c) 2022 Continental Automotive GmbH
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
  attr_accessor :target, :source, :shadow, :merged, :megamergeable, :merge_conflict
  attr_accessor :merge_commit_message, :megamerge, :merge_commit, :children, :reviews_done, :mergeable_state, :rebaseable


  def self.from_pull_request(pull)
    new(
      id: pull.id,
      organization: pull.repository.organization,
      repository: pull.repository.repository,
      target: pull.target_branch,
      source: pull.source_branch,
      merged: pull.merged?,
      megamergeable: pull.megamergeable?,
      mergeable_state: pull.mergeable_state,
      merge_conflict: pull.merge_conflict?,
      merge_commit: pull.merge_commit_sha,
      merge_commit_message: pull.merge_commit_message,
      megamerge: pull.parent? || !pull.children&.empty?,
      reviews_done: pull.reviews_done?,
      rebaseable: pull.rebaseable?,
      children: children(pull)
    )
  end

  def self.children(pull)
    (pull.children&.map { |child| from_pull_request(child) } if pull.respond_to?(:children))
  end

  def attributes
    {
      'id' => '',
      'organization' => '',
      'repository' => '',
      'target' => '',
      'source' => '',
      'merged' => '',
      'megamergeable' => '',
      'mergeable_state' => '',
      'merge_conflict' => '',
      'merge_commit' => '',
      'merge_commit_message' => '',
      'megamerge' => '',
      'reviews_done' => '',
      'rebaseable' => '',
      'children' => ''
    }
  end
end
