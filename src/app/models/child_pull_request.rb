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

class ChildPullRequest < PullRequest
  include ChildPullRequest::ChildActions
  attr_accessor :parent, :parent_full_name

  def self.from_params(params)
    pr = super(params)
    pr.source_branch = pr.repository.default_branch if pr.source_branch.blank?
    pr.body = params[:body] if params[:body]

    return pr.find_id if pr.wrong_id?

    pr.refresh!
  end

  def self.from_child_decoding_gql(gql_data, decoded, parent)
    pr = from_gql(gql_data)
    pr.merge_method = decoded[:merge_method]
    pr.config_files = decoded[:config_files] if decoded[:config_files] # only if PR is of new kind
    pr.parent = parent
    pr
  end

  def parent
    return @parent unless @parent.nil?
    temp_body = MegaMerge::ChildDecoder.decode(body)
    return nil if temp_body.nil?
    @parent = MetaPullRequest.from_parent_decoding(temp_body[:config])&.refresh!
  end

  def parent_id=(value)
    @parent_id = value.to_i.positive? ? value.to_i : 0
  end

  def parent_id
    @parent_id ||= parent.id
  end

  def parent_full_name
    @parent_full_name ||= parent.repository.name
  end

  def target_branch_valid?
    !repository.branches.find { |branch| branch[:name] == target_branch}.nil?
  end

  def status
    if !target_branch_valid?
      { text: "Target Branch does not exist!", color: 'danger', blocking: true }
    else
      super
    end
  end

  def removeable?
    return false if merged?
    return false if parent && parent_id == parent.id && (parent.closed? || !parent.remove_subs_possible?)
    true
  end

  # params: none
  # description: Checks if the child pr is already a part of its parent pr
  # return: new child pr status if it is a part of its parent pr
  # return: PullRequest.existing_status if child pr is not a part of its parent pr
  def existing_status
    if parent && (parent.id != parent_id || parent.repository.name != parent_full_name) # this might be very expensive right now
      { text: "This is already part of PR<br>#{parent.repository.repository} ##{parent.id}", color: 'danger', blocking: true }
    else
      super
    end
  end
end
