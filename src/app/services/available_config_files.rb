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

class AvailableConfigFiles
  include Callable

  def initialize(organization, repo, target_branch, source_branch)
    @organization = organization
    @repo = repo
    @target_branch = target_branch
    @source_branch = source_branch
  end

  def call
    return filenames.first if filenames.count == 1

    filenames
  end

  private

  attr_accessor :target_branch, :source_branch

  def filenames
    GitHub::GQL.add(repository.name, GitHub::GQL.QUERY, create_gql_list_files(@organization, @repo, branch))
    ret = GitHub::GQL.execute

    files = ret[:repository][:object][:entries].map do |file|
      if (file[:name].end_with? ".gitmodules") || (file[:name].end_with? ".xml")
        file[:mode] == 0o120000 ? file[:object][:text] : file[:name]
      end
    end

    files.uniq.compact
  end

  def branch
    @branch ||=
      if repository.branch_exists?(source_branch)
        source_branch
      else
        target_branch
      end
  end

  def repository
    @repository ||= Repository.new(organization: @organization, repository: @repo)
  end

  def create_gql_list_files(org, repo, branch) 
    "
    
      repository(owner: \"#{org}\", name: \"#{repo}\") {
        object(expression: \"#{branch}:\") {
          ... on Tree {
            entries {
              name
              type
              mode
    
              object {
                ... on Blob {
                  byteSize
                  text
                  isBinary
                }
              }
            }
          }
        }
      }
    
    "
  end
end
