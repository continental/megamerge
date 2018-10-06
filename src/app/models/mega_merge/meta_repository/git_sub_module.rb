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

module MegaMerge
  module MetaRepository
    class GitSubModule < BaseModel
      include ActiveModel::Serialization

      SUB_MODULE_MODE = '160000'
      SUB_MODULE_TYPE = 'commit'

      attr_accessor :path, :source_branch, :repository, :parent_repository

      def attributes
        { 'path' => nil, 'type' => nil, 'mode' => nil, 'sha' => nil }
      end

      def self.mode
        SUB_MODULE_MODE
      end

      def self.type
        SUB_MODULE_TYPE
      end

      def mode
        self.class.mode
      end

      def type
        self.class.type
      end

      def target_branch
        @target_branch || 'master'
      end

      def target_branch=(value)
        @target_branch = (value == '.' ? current_branch : value)
      end

      def revision
        @revision ||= fetch_revision
      end
      alias sha revision

      def revision=(value)
        @revision = value
        @dirty = true
      end

      def remove!
        @remove = true
      end

      def remove?
        @remove || false
      end

      def dirty?
        @dirty || false
      end

      def section_name
        "submodule \"#{path}\""
      end

      private

      # To save requests, only fetch the revision if absolutly needed.
      def fetch_revision
        file = parent_repository.contents(path: path + '?ref=' + source_branch)
        return nil if file[:type] != 'submodule'
        file[:sha]
      rescue Octokit::NotFound
        nil
      end
    end
  end
end
