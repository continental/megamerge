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
          "\n\nDo **NOT** push on `#{@meta_pr.shadow_branch}` branch directly! Use `#{@meta_pr.source_branch}` instead!"
        ]
      end
    end

    private

    def configuration
      {
        type: Encoder::PARENT_TYPE,
        config_file: meta_pr.config_file,
        source_branch: meta_pr.source_branch,
        squash: meta_pr.squash?,
        sub_repo_actions: meta_pr.child_actions,
        children: children.map { |child| encode_child(child) }
      }
    end

    def encode_child(child)
      {
        id: child.id,
        name: child.repository.name
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
