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

RSpec.describe MegaMerge::MetaRepository::GoogleConfig do
  before(:each) do
    xml = <<~MANIFEST
      <manifest>
      </manifest>
    MANIFEST
    allow_any_instance_of(described_class).to receive(:decoded_contents).and_return(xml)
  end

  describe '#projects' do
    let(:instance) { described_class.new }

    it 'should parse the available projects' do
      expect(instance.projects.count).to eq(4)
    end

    it 'should set the default remote when the remote is missing' do
      project = instance.projects['iip/sw.base.pkg.dtgensrvr']
      expect(project.project_remote).to eq(instance.remotes.first.second)
    end

    it 'should parse available remotes' do
      expect(instance.remotes.count).to eq(2)
    end
  end

  describe '#update_hash!' do
    let(:instance) { described_class.new }

    it 'should update the xml hash' do
      action = SubRepoAction.from_params(
        action: SubRepoAction::UPDATE_BY_HASH,
        organization: 'iip',
        repository: 'sw.pkg.cdef',
        ref: 'abcd'
      )
      instance.update_hash!(action)
      expect(instance.projects[action.name].revision).to eq(action.ref)
    end
  end

  describe '#remove!' do
    let(:instance) { described_class.new }

    it 'should remove an existing repo from the xml' do
      action = SubRepoAction.from_params(
        action: SubRepoAction::REMOVE,
        organization: 'iip',
        repository: 'sw.pkg.cdef'
      )
      expect(instance.projects.count).to eq(4)
      instance.remove_entry!(action)
      expect(instance.projects[action.name]).to be(nil)
      expect(instance.projects.count).to eq(3)
    end

    it 'should be a non action if the removed repository is missing' do
      action = SubRepoAction.from_params(
        action: SubRepoAction::REMOVE,
        organization: 'iip',
        repository: 'imaginary'
      )
      instance.remove_entry!(action)
      expect(instance.projects[action.name]).to be(nil)
      expect(instance.projects.count).to eq(4)
    end

    it 'should do nothing if applied twice to the same action' do
      action = SubRepoAction.from_params(
        action: SubRepoAction::REMOVE,
        organization: 'iip',
        repository: 'sw.pkg.cdef'
      )
      expect(instance.projects.count).to eq(4)
      instance.remove_entry!(action)
      expect(instance.projects[action.name]).to be(nil)
      expect(instance.projects.count).to eq(3)

      instance.remove_entry!(action)
      expect(instance.projects[action.name]).to be(nil)
      expect(instance.projects.count).to eq(3)
    end
  end
end
