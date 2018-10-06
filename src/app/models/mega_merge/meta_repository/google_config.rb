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
    # Manages GoogleRepo config XML
    class GoogleConfig < MetaConfig
      # TODO: Use default remote for google repo
      # TODO: Add path in UI
      def update_hash!(child_change)
        projects[child_change.name]&.revision = child_change.sha
      end

      def add_or_update_entry!(child_change)
        return update_hash!(child_change) if projects[child_change.name]
        add_entry!(child_change)
      end

      def add_entry!(child_change)
        node = child_change.to_xml(content, remote: default_remote)
        content.manifest.add_child(node)
        add_google_project!(projects, node)
      end

      def remove_entry!(child_change)
        projects[child_change.name]&.remove
        projects.delete(child_change.name)
      end

      def projects
        @projects ||= content.xpath('//project').each_with_object({}) do |project, hash|
          add_google_project!(hash, project)
        end
      end

      def remotes
        @remotes ||= content.xpath('//remote').each_with_object({}) do |remote, hash|
          hash[remote[:name]] = Remote.new(name: remote[:name],
                                           server: remote[:fetch],
                                           uri: remote[:fetch])
        end
      end

      protected

      def add_google_project!(hash, xml_project)
        gp = GoogleProject.new(xml_project)
        gp.project_remote = find_remote(gp)
        return unless gp.project_remote&.valid?
        hash[gp.key] = gp
      end

      def default_remote
        @default_remote ||= remotes.first&.second
      end

      def find_remote(project)
        return default_remote if project.remote.nil?
        remotes[project.remote]
      end

      def content
        @content ||= Nokogiri::XML(decoded_contents)
      end
    end
  end
end
