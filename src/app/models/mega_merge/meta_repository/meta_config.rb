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
    # Abstract class for managing configs
    # Super class needs to implement:
    #   - content
    #   - projects
    #   - update_hash!(child_change)
    #   - update_by_branch!(child_change)
    #   - add_or_update_entry!(child_change)
    #   - add_entry!(child_change)
    #   - remove_entry!(child_change)
    class MetaConfig < BaseModel
      attr_accessor :repository, :config_files, :branch_name

      def initialize(repository, config_files, branch_name)
        @repository = repository
        @config_files = config_files
        @branch_name = branch_name
      end

      def update_hash!(child, meta_pr) #children_pullrequest
        # full_identifier is array since child can occur in multiple config files
        child.full_identifier.each do |_name|
          _sha = child.merge_commit_sha
          _sha = child.source_branch_sha if meta_pr.draft? # dev checkout get consistently his changes without updates from others (the temporary merge hash would have master updates included)
          return if projects[_name]&.revision == _sha # might be costly in submodule case

          logger.info "updating hash of #{_name} from #{projects[_name]&.revision} to #{_sha}"
          projects[_name]&.revision = _sha
        end
      end

      def update!(children, meta_pr)
        children.each { |child| update_hash!(child, meta_pr) }
        nil
      end

      def outdated?(children, meta_pr)
        return true if dirty?
        result = false
        children.each do |child|
          child.full_identifier.each do |_name|
            if projects[_name] &&
              (projects[_name].revision != child.merge_commit_sha && !meta_pr.draft?) ||
            projects[_name] &&
              (projects[_name].revision != child.source_branch_sha && meta_pr.draft?)
              return true
            end
            # && child.merge_commit_sha.present? # disabled because PR creation fails as no commit is created at all
          end
        end
        result
      end

      def dirty?
        projects.any? {|_, p| p.dirty? }
      end

    
      def inconsistent?(children)
        result = false
        children.each do |child|
          child.full_identifier.each do |_name|
            unless projects.include? _name
              return true
            end
          end
        end
        result
      end

      def commit_changes(commit_to_base_on, source_branch, commit_message)
        tree_sha = repository.create_tree(tree_changes, base_tree: commit_to_base_on[:commit][:tree][:sha]).sha
        commit_hash = repository.create_commit(commit_message, tree_sha, commit_to_base_on[:sha]).sha
        repository.update_branch(source_branch, commit_hash, true)
        commit_hash
      end

      protected


      def create_gql_files_read(org, repo, branch, files)
        file_query = (files.collect{|file|
          hash = "h_#{file.hash.abs}"
          "
          #{hash}: file(path: \"#{file}\") {
            oid
            type
            object {
              ... on Blob {
                text
              }
            }
          },
          "
        }).join

        "
        repository(owner: \"#{org}\", name: \"#{repo}\") {
          object(expression: \"#{branch}\") {
            ... on Commit {
              #{file_query}
            }
          }
        }
        "
      end


      def preload_files(files)
        GitHub::GQL.add(repository.name, GitHub::GQL.QUERY, create_gql_files_read(repository.organization, repository.repository, branch_name, files))
        ret = GitHub::GQL.execute

        @file_cache = {} if @file_cache.nil?
        files.each do |file|
          type = ret.dig(:repository, :object, "h_#{file.hash.abs}".to_sym, :type)
          if type.eql? ("commit") # just a submodule oid
            @file_cache[file] = ret.dig(:repository, :object, "h_#{file.hash.abs}".to_sym, :oid)
          elsif type.eql? ("blob") # real file (xml)
            @file_cache[file] = ret.dig(:repository, :object, "h_#{file.hash.abs}".to_sym, :object, :text)
          end
          raise "ERROR: Config file #{file} was requested but not found in the repository!" if @file_cache[file].nil?
        end
      end




      def retrieve_file_on_branch(branch, file)
        repository.contents(path: file + '?ref=' + branch).content
      end

      def decoded_contents(file)
        preload_files(config_files) if @file_cache.nil?
        @file_cache[file] ||= decode_contents(retrieve_file_on_branch(branch_name, file))
      end

      def decode_contents(content)
        Base64.decode64(content)
      end
    end
  end
end
