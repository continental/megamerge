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
    class GoogleProject
      attr_accessor :project_remote, :config_file

      def initialize(xml, config_file)
        @config_file = config_file
        @xml = xml
      end

      def name
        @name ||= @xml[:name]
      end

      def remote
        @remote ||= @xml[:remote]
      end

      def revision
        @revision ||= @xml[:revision]
      end

      def config_file
        @config_file
      end

      def revision=(value)
        @dirty = true if revision != value
        @xml[:revision] = value
        @revision = value
      end

      def org
        project_remote.organization
      end

      def key
        "#{project_remote.organization}/#{name}/#{config_file}"
      end

      def remove!
        @remove = true
        @xml.remove
      end

      def remove?
        @remove || false
      end

      def dirty?
        @dirty || false
      end

    end
  end
end
