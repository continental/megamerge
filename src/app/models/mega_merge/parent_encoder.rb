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
  # Encodes the Meta repository state into the pull request body
  class ParentEncoder
    attr_reader :meta_pr, :children

    def self.encode(meta_pr)
      new(meta_pr).encode
    end

    def initialize(meta_pr)
      @meta_pr = meta_pr
      @children = meta_pr.children
    end

    def encode
      Encoder.encode(body: meta_pr.body, config: configuration) do
        [
          header,
          children_body,
          "\n\n:x: Do **NOT** press the _merge button_ down below!
            \n:x: Do **NOT** delete this description, but add your optional description above this generated content!
            \n:x: Do **NOT** set this PR ready_for_review from GitHub GUI, use MM GUI instead!"

        ]
      end
    end

    private

    def configuration
      {
        type: Encoder::PARENT_TYPE,
        config_files: meta_pr.config_files,
        source_branch: meta_pr.source_branch,
        merge_method: meta_pr.merge_method,
        automerge: meta_pr.automerge?,
        merge_commit_message: meta_pr.merge_commit_message,
        children: children.map { |child| encode_child(child) },
        api_url: "#{Rails.application.config.url}/api/v1"
      }
    end

    def encode_child(child)
      {
        id: child.id,
        name: child.repository.name,
        merge_method: child.merge_method,
        config_files: child.config_files
      }
    end

    def header
      <<~HEADER
        ---
        ## Mega Merge
        #{Rails.application.config.url}/view/#{meta_pr.slug}
      HEADER
    end

    def children_body
      buf = +"### SubRepos:\n"
      children.each do |child|
        buf << "* #{child.md_link}\n" if child.id?
      end
      buf << "\n"
      buf
    end
  end
end
