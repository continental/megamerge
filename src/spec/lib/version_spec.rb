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

require 'rails_helper'

RSpec.describe Version do
  describe 'initialize correct version numbers' do
    it 'should parse version number correctly' do
      version = Version.new('0.1.2')
      expect(version.major).to eq(0)
      expect(version.minor).to eq(1)
      expect(version.patch).to eq(2)
    end

    it 'should parse multinumber version numbers correctly' do
      version = Version.new('11.111.1111')
      expect(version.major).to eq(11)
      expect(version.minor).to eq(111)
      expect(version.patch).to eq(1111)
    end

    it 'should handle missing patch number' do
      version = Version.new('1.2')
      expect(version.major).to eq(1)
      expect(version.minor).to eq(2)
      expect(version.patch).to eq(0)
    end

    it 'should handle missing minor number' do
      version = Version.new('1')
      expect(version.major).to eq(1)
      expect(version.minor).to eq(0)
      expect(version.patch).to eq(0)
    end

    it 'should default to 0' do
      version = Version.new()
      expect(version.major).to eq(0)
      expect(version.minor).to eq(0)
      expect(version.patch).to eq(0)
    end
  end

  describe 'it should compare with other version numbers' do
    it 'should be equal' do
      v1 = Version.new('1.2.3')
      v2 = Version.new('1.2.3')
      expect(v1).to eq(v2)
    end

    it 'should compare as smaller with major' do
      v1 = Version.new('0.2.3')
      v2 = Version.new('1.2.3')
      expect(v1).to be < v2
    end

    it 'should compare as smaller with minor' do
      v1 = Version.new('1.1.3')
      v2 = Version.new('1.2.3')
      expect(v1).to be < v2
    end

    it 'should compare as smaller with patch' do
      v1 = Version.new('1.2.2')
      v2 = Version.new('1.2.3')
      expect(v1).to be < v2
    end
  end
end
