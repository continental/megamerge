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

class ReadXMLFiles

  def initialize(files, organization, repo, target_branch, source_branch)
    # In: files [string-array], .xml config files
    #   : organization [string], GitHub org
    #   : repo [string], Meta repository
    #   : target_branch [string],
    #   : source_branch [string],
    @all_config_files = files
    @organization = organization
    @repo = repo
    @target_branch = target_branch
    @source_branch = source_branch

    load_files(files)

  end

  attr_accessor :target_branch, :source_branch


  def load_files(files)
    # In: files [array], all found config files
    # Out: @file_cache [array], all files content
    GitHub::GQL.add(repository.name, GitHub::GQL.QUERY, create_gql_files_read(@organization, @repo, branch, files))
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

  def top_level_xml
    included_files = @all_config_files.flat_map do |config|
      content(config).xpath('//include').filter_map do |xml|
        xml[:name] if xml[:groups].nil? || !(xml[:groups].split(",").include? "mm-ignore")
      end
    end

    top_level_manifests = @all_config_files - included_files
    top_level_manifests
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

  def retrieve_file_on_branch(branch, file)
    @repository.contents(path: file + '?ref=' + branch).content
  end

  def decoded_contents(file)
    load_files(@all_config_files) if @file_cache.nil?
    @file_cache[file] ||= decode_contents(retrieve_file_on_branch(branch, file))
  end

  def decode_contents(content)
    Base64.decode64(content)
  end

  def content(file)
    @content = {} if @content.nil?
    @content[file] ||= Nokogiri::XML(decoded_contents(file))
  end

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

end
