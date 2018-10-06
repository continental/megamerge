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
      attr_accessor :repository, :file_name, :branch_name
      attr_writer :commit_title

      def perform_actions!(child_actions)
        child_actions.each { |_, action| perform_action!(action) }
      end

      def perform_action!(child_action)
        case child_action.action
        when SubRepoAction::ADD
          logger.warn("#{child_action.name} - ADD not implemented")
        #   add_or_update_entry!(child_action)
        when SubRepoAction::UPDATE_BY_HASH, SubRepoAction::UPDATE_BY_BRANCH
          update_hash!(child_action)
        when SubRepoAction::REMOVE
          remove_entry!(child_action)
        else
          logger.warn("#{child_action.name} - Unknown action type: #{child_action.action}")
        end
        child_action.done!
      end

      def write!(target_branch, child_actions, force_commit: false)
        perform_actions!(child_actions)
        target_file = retrieve_file_on_branch(target_branch)
        return nil if !file_altered?(target_file) && !force_commit
        update_contents!(target_file.sha, target_branch)
      end

      def update_contents!(sha, branch)
        repository.update_contents(
          file_name,
          commit_title,
          sha,
          content.to_s,
          branch: branch
        )[:commit][:sha]
      end

      def commit_title
        @commit_title.presence || "Megamerge updated config file by #{`hostname`}"
      end

      protected

      def file
        @file ||= retrieve_file_on_branch(branch_name)
      end

      def file_altered?(target_file)
        decode_contents(target_file.content) != content.to_s
      end

      def retrieve_file_on_branch(branch)
        repository.contents(path: file_name + '?ref=' + branch)
      end

      def decoded_contents
        @decoded_contents ||= decode_contents(file.content)
      end

      def decode_contents(content)
        Base64.decode64(content)
      end
    end
  end
end
