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

      def update_hash!(child_change)
        projects[child_change.name]&.revision = child_change.sha
      end

      def remove_entry!(child_change)
        content.delete_section(projects[child_change.name]&.section_name)
        projects[child_change.name]&.remove!
      end

      def perform_actions!(child_actions)
        super
        commit_projects! unless updated_projects.empty?
      end

      protected

      def file_name
        @file_name || FILE_NAME
      end

      def content
        @content ||= IniFile.new(content: decoded_contents)
      end

      private

      def repositories
        repositories = {}
        content.each_section do |section_name|
          section = content[section_name]
          return nil if invalid_section?(section)
          repo = Repository.from_url(section['url'])
          repositories[repo.name] = GitSubModule.new(
            parent_repository: repository,
            repository: repo,
            source_branch: branch_name,
            target_branch: section['branch'],
            path: section['path']
          )
        end
        repositories
      end

      def invalid_section?(section)
        if section['path'].nil? || section['url'].nil?
          @logger.warn("#{FILENAME} #{section_name} is missing 'path' or 'url'")
          return true
        end
        false
      end

      def updated_projects
        @updated_projects ||= projects.select do |_, p|
          (p.dirty? && !p.sha.nil?) || p.remove?
        end
      end

      def project_tree(sha)
        @project_tree ||= {}
        @project_tree[sha] ||= Hash[
          repository.tree(sha, recursive: true).tree.map { |file| [file.path, file] }
        ]
      end

      def apply_tree_updates!(sha)
        updated_projects.values.each do |project|
          if project.remove?
            project_tree(sha).delete(project.path)
          else
            project_tree(sha)[project.path].sha = project.sha
          end
        end
        # Sawyer converts hashes into array representation. Need to convert it back
        # and remove all the extra data github sends us.
        project_tree(sha).values.map { |arr| arr.to_h.slice(:path, :mode, :type, :sha) }
      end

      # To delete a submodule file in GitHub, we need to read out the entire
      # current git tree, remove the files we want to delete, then write
      # the new tree back to github without setting a base tree.
      def commit_projects!
        latest_commit = repository.commit(branch_name)
        new_tree = repository.create_tree(
          apply_tree_updates!(latest_commit.commit.tree.sha)
        )
        new_commit = repository.create_commit(
          'Update submodules',
          new_tree.sha,
          [latest_commit.sha]
        )
        repository.update_branch(branch_name, new_commit.sha)
      end
    end
  end
end
