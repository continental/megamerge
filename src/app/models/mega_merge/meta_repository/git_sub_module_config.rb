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
    # Handles the reading and updating of git submodules on github
    class GitSubModuleConfig < MetaConfig
      FILE_NAME = '.gitmodules'

      def projects
        @projects ||= repositories
      end

      def updated_projects
        @updated_projects ||= projects.select do |_, p|
          (p.dirty? && !p.sha.nil?)
        end
      end

      def find_includes(configs = "", depth = 5) # dummy

      end

      def file_name
        @file_name || FILE_NAME
      end

      def tree_changes
        new_blob_sha = repository.create_blob(Base64.encode64(content.to_s), "base64")
        new_tree = [{:path => file_name, :mode => "100644", :type => "blob", :sha => new_blob_sha}]
        apply_tree_updates!(new_tree)
        new_tree
      end

      protected

      def content
        @content ||= IniFile.new(content: decoded_contents(file_name))
      end

      private

      def repositories
        repositories = {}
        content.each_section do |section_name|
          section = content[section_name]
          return nil if invalid_section?(section)
          repo = repository.from_url(section['url'])
          logger.debug("Url: #{section['url']} Parent: #{repository.name} Sub: #{repo.name}")
          new_sub = GitSubModule.new(
            parent_repository: repository,
            repository: repo,
            source_branch: branch_name,
            path: section['path']
          )
          repositories[new_sub.key] = new_sub
        end
        repositories
      end

      def invalid_section?(section)
        if section['path'].nil? || section['url'].nil?
          logger.warn("#{FILENAME}: #{section_name} is missing 'path' or 'url'")
          return true
        end
        false
      end

      def apply_tree_updates!(tree)
        updated_projects.values.each do |project|
          tree.push({:path => project.path, :mode => '160000', :type => 'commit', :sha => project.sha})
          logger.info "#{project.path} now points to #{project.sha}"
        end
      end


    end
  end
end
