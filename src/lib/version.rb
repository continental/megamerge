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

# Simple semantic versioning
class Version
  include Comparable

  attr_accessor :major, :minor, :patch

  def initialize(version = '')
    return nil if version.nil?
    versions = version.split('.').map(&:to_i)
    @major = versions[0] || 0
    @minor = versions[1] || 0
    @patch = versions[2] || 0
  end

  def <=>(other)
    return (major <=> other.major) unless (major <=> other.major).zero?
    return (minor <=> other.minor) unless (minor <=> other.minor).zero?
    patch <=> other.patch
  end

  def to_s
    "#{major}.#{minor}.#{patch}"
  end
end
