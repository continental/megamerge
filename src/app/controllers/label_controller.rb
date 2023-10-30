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

class LabelController < ApplicationController
  def labels
    render json: Repository.from_params(params).labels.map(&:to_h)
  end

  def labels_for_issue
    render json: Repository.from_params(params)
      .labels_for_issue(params[:issue_num]).map(&:to_h)
  end

  def add_labels_to_issue
    render json: Repository.from_params(params)
      .add_labels_to_an_issue(params[:issue_num], params[:_json]).map(&:to_h)
  end

  def replace_all_labels
    render json: Repository.from_params(params)
      .replace_all_labels(params[:issue_num], params[:_json]).map(&:to_h)
  end
end
