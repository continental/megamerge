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

class BaseModel
  include ActiveModel::Validations
  include ActiveModel::Model
  include ActiveModel::AttributeMethods

  def self.logger
    Rails.logger
  end

  def logger
    self.class.logger
  end

  def self.from_params(params)
    new(keep_attributes(params))
  end

  def self.keep_attributes(params)
    params.symbolize_keys.select do |key, _|
      attribute_method?(key)
    end
  end

  # Merges 2 class instances
  def merge_instance(other)
    dup.merge_instance!(other)
  end

  def merge_instance!(other)
    return self if other.nil?
    return self if equal?(other)
    other.instance_variables.each do |var|
      instance_variable_set(var, other.instance_variable_get(var))
    end
    self
  end
end
