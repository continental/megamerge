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

      def find_includes(configs = config_files, depth = 5)       
        config_files.union(configs)
        preload_files(configs) 
        parse_projects(configs)
      
        return if depth == 0 

        new_configs = configs.flat_map do |config|
          content(config).xpath('//include').filter_map do |xml| 
            xml[:name] if xml[:groups].nil? || !(xml[:groups].split(",").include? "mm-ignore")
          end
        end

        find_includes(new_configs, depth - 1) unless new_configs.empty? # recurse
      end


      def projects
        parse_projects(config_files) if @projects.nil?
        @projects
      end

      def parse_projects(config_files)
        # read all repositories (projects) and store them in key value pair
        # config_files = list of manifest filenames, e.g [default.xml, another_manifest.xml]
        # gp.key = <org>/<repo>/default.xml> , e.g vni-ce-gen-tst2/sub1SoZi/default.xml
        # return projects: dict of GoogleProjects (Sub Repos), key is gp.key
        # multiple occurrences of repo are only stored once (due to chosen key) -> all are updated, duplicates are handled in "def updated_projects"
        @projects = Hash.new if @projects.nil?

        config_files.each do |config_file|
          content(config_file).xpath('//project').map do |project, hash|
            gp = GoogleProject.new(project, config_file)
            gp.project_remote = find_remote(gp)
            @projects[gp.key] = gp if gp.project_remote&.valid?
          end
        end

      end

      def remotes(config_file)
        @remotes= {} if @remotes.nil?
        @remotes[config_file] ||= content(config_file).xpath('//remote').each_with_object({}) do |remote, hash|
          hash[remote[:name]] = Remote.new(name: remote[:name],
                                           server: remote[:fetch].chomp("/"),
                                           uri: remote[:fetch].chomp("/"))
        end
      end

      def updated_projects 
        @updated_projects ||= projects.select do |_, p|
          (p.dirty? && !p.revision.nil?) || p.remove?
        end
        # update multiple occurrences of repo in manifest
        # this code part can be omitted when used key becomes unique -> TODO: find new key (and make sure MM does not open duplicate sub if new key is established)
        # If there are multiple entries of a project/sub-repo, only the first entry in the xml will be updated and then stored
        # Open the xml file again (gp_tmp) and update every project revision, that is in the "updated revision list" (gp) from
        # MM operation.
        @updated_projects.each do |_, gp|
          content(gp.config_file).xpath('//project').map do |project, hash|
            gp_tmp = GoogleProject.new(project, gp.config_file)
            gp_tmp.project_remote = find_remote(gp_tmp)
            if gp_tmp.project_remote&.valid?
              if gp.key == gp_tmp.key # if this sub repo was updated, update its duplicate entries
                gp_tmp.revision = gp.revision
              end
            end
          end
        end
        @updated_projects
      end

      def updated_config_files
        updated_projects.map{ |_, proj| proj.config_file }.compact.uniq
      end

      def tree_changes
        # TODO: use GQL
        # Return key array eg {path=>"default.xml", mode=>10..}
        # 100644 means the file is a normal file
        updated_config_files.map do |config_file|
          new_blob_sha = repository.create_blob(Base64.encode64(content(config_file).to_s), "base64")
          {:path => config_file, :mode => "100644", :type => "blob", :sha => new_blob_sha}
        end
      end

      protected

      def default_remote(config_file)
        @default_remote = {} if @default_remote.nil?
        res = content(config_file).xpath('//default')[0]
        return nil if res.nil?
        @default_remote[config_file] ||= remotes(config_file)[res[:remote]]
      end

      def find_remote(project)
        if project.remote.nil? and default_remote(project.config_file).nil?
          raise MegamergeException,"No default remote or project remote was given for subrepo #{project.name} in #{project.config_file}"
        end
        return default_remote(project.config_file) if project.remote.nil?
        remotes(project.config_file)[project.remote]
        end

      def content(file)
        @content = {} if @content.nil?
        @content[file] ||= Nokogiri::XML(decoded_contents(file))
      end
    end
  end
end
