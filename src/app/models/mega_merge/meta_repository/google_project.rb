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
      attr_accessor :project_remote

      def initialize(xml)
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

      def revision=(value)
        @xml[:revision] = value
      end

      def target_branch
        @target_branch ||= (@xml[:targetbranch] || 'master')
      end

      def key
        "#{project_remote.organization}/#{name}"
      end

      def remove
        @xml.remove
      end

      def to_xml
        @xml
      end
    end
  end
end
