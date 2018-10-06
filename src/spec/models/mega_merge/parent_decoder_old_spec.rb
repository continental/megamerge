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

RSpec.describe MegaMerge::ParentDecoderOld do
  def make_template(options = {})
    options.default = ''
    <<~TEMPLATE
      #{options[:body]}<!-- BEGIN MEGAMERGE -->
      ---
      ## Mega Merge
      http://megamerge.local/view/id-ci-starter/test.megamerge.master/44
      <!-- configuration: #{options[:file]} #{options[:source]} #{options[:squash]} -->

      ### SubRepos:
      #{options[:sub_repos]&.map do |sub_repo|
          next '' if sub_repo.empty?
          sub_repo.default = ''
          "* #{sub_repo[:name]}##{sub_repo[:id]}"
        end&.join("\n")}

      <!-- END MEGAMERGE -->
    TEMPLATE
  end

  describe '#parse(text)' do
    it 'parses valid state without body' do
      options = {
        file: 'test.xml',
        source: 'test_branch',
        squash: 'true',
        sub_repos: [{ id: 1, name: 'test/repo' }]
      }
      result = described_class.new(make_template(options)).decode

      expect(result[:config][:source_branch]).to eq(options[:source])
      expect(result[:config][:config_file]).to eq(options[:file])
      expect(result[:config][:squash]).to be(true)
      expect(result[:config][:children].size).to eq(1)
      result[:config][:children].each_with_index do |pr, i|
        expect(pr[:id]).to eq(options[:sub_repos][i][:id])
        expect(pr[:name]).to eq(options[:sub_repos][i][:name])
      end
    end

    it 'should parse the template with body' do
      options = {
        file: 'test.xml',
        body: "This is a body\nIt has multiple lines\n",
        source: 'test_branch',
        squash: 'true',
        sub_repos: [{ id: 1, name: 'test/repo' }]
      }
      result = described_class.new(make_template(options)).decode

      expect(result[:body]).to eq(options[:body])
      expect(result[:config][:source_branch]).to eq(options[:source])
      expect(result[:config][:config_file]).to eq(options[:file])
      expect(result[:config][:squash]).to be(true)
      expect(result[:config][:children].size).to be(1)
      result[:config][:children].each_with_index do |pr, i|
        expect(pr[:id]).to eq(options[:sub_repos][i][:id])
        expect(pr[:name]).to eq(options[:sub_repos][i][:name])
      end
    end

    it 'parses a valid state without squash defined' do
      options = {
        file: 'test.xml',
        source: 'test_branch',
        sub_repos: [{ id: 1, name: 'test/repo' }]
      }
      result = described_class.new(make_template(options)).decode

      expect(result[:config][:source_branch]).to eq(options[:source])
      expect(result[:config][:config_file]).to eq(options[:file])
      expect(result[:config][:squash]).to be(true)
      expect(result[:config][:children].size).to be(1)
      result[:config][:children].each_with_index do |pr, i|
        expect(pr[:id]).to eq(options[:sub_repos][i][:id])
        expect(pr[:name]).to eq(options[:sub_repos][i][:name])
      end
    end

    it 'parses a valid state with multiple sub repos' do
      options = {
        file: 'test.xml',
        source: 'test_branch',
        sub_repos: [
          { id: 1, name: 'test/repo' },
          { id: 2, name: 'tes2/rep2' }
        ]
      }
      result = described_class.new(make_template(options)).decode

      expect(result[:config][:source_branch]).to eq(options[:source])
      expect(result[:config][:config_file]).to eq(options[:file])
      expect(result[:config][:squash]).to be(true)
      expect(result[:config][:children].size).to be(2)

      result[:config][:children].each_with_index do |pr, i|
        expect(pr[:id]).to eq(options[:sub_repos][i][:id])
        expect(pr[:name]).to eq(options[:sub_repos][i][:name])
      end
    end

    it 'parses valid config with 0 sub repos' do
      options = {
        file: 'test.xml',
        source: 'test_branch',
        sub_repos: []
      }
      result = described_class.new(make_template(options)).decode

      expect(result[:config][:source_branch]).to eq(options[:source])
      expect(result[:config][:config_file]).to eq(options[:file])
      expect(result[:config][:squash]).to be(true)
      expect(result[:config][:children].size).to be(0)
    end

    it 'should parse squash as false if it is set as false' do
      options = {
        file: 'test.xml',
        source: 'test_branch',
        squash: 'false',
        sub_repos: []
      }
      result = described_class.new(make_template(options)).decode

      expect(result[:config][:source_branch]).to eq(options[:source])
      expect(result[:config][:config_file]).to eq(options[:file])
      expect(result[:config][:squash]).to be(false)
      expect(result[:config][:children].size).to be(0)
    end

    it 'should return nil if file is missing' do
      options = {
        source: 'test_branch',
        sub_repos: []
      }
      result = described_class.new(make_template(options)).decode
      expect(result).to be(nil)
    end

    it 'should return nil if source is missing' do
      options = {
        file: 'text.xml',
        sub_repos: []
      }
      result = described_class.new(make_template(options)).decode
      expect(result).to be(nil)
    end

    it 'should ignore invalid sub repos' do
      options = {
        file: 'test.xml',
        source: 'test_branch',
        sub_repos: [
          { id: 1, name: 'test/repo' },
          { name: 'tes2/rep2' },
          { id: 2 },
          {}
        ]
      }

      result = described_class.new(make_template(options)).decode

      expect(result[:config][:source_branch]).to eq(options[:source])
      expect(result[:config][:config_file]).to eq(options[:file])
      expect(result[:config][:squash]).to be(true)
      expect(result[:config][:children].size).to be(1)

      result[:config][:children].each_with_index do |pr, i|
        expect(pr[:id]).to eq(options[:sub_repos][i][:id])
        expect(pr[:name]).to eq(options[:sub_repos][i][:name])
      end
    end

    it 'should have type of parent' do
      options = {
        file: 'test.xml',
        source: 'test_branch',
        squash: 'true',
        type: MegaMerge::Encoder::PARENT_TYPE,
        sub_repos: [{ id: 1, name: 'test/repo' }]
      }
      result = described_class.new(make_template(options)).decode

      expect(result[:config][:type]).to eq(options[:type])
    end
  end
end
