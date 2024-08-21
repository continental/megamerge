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


      def config_files
        path
      end

      def key
        "#{org}/#{name}/#{path}"
      end

      def name
        repository.repository
      end

      def org
        repository.organization
      end


      def revision
        @revision ||= fetch_revision
      end
      alias sha revision

      def revision=(value)
        @dirty = true if revision != value
        @revision = value
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
        logger.debug("fetch_revision #{source_branch}: #{path}")
        file = parent_repository.contents(path: path + '?ref=' + source_branch)
        return nil if file[:type] != 'submodule'
        file[:sha]
      rescue Octokit::NotFound
        nil
      end
    end
  end
end
