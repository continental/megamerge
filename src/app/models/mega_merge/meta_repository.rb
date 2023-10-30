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
    class InvalidConfigFileError < StandardError; end

    def self.create(config_files, repository, branch)

      return GoogleConfig.new(repository, config_files, branch) if xml_file?(config_files)
      return GitSubModuleConfig.new(repository, config_files, branch) if gitmodules_file?(config_files)
      raise InvalidConfigFileError, config_files
    end

    def self.xml_file?(config_files)
      config_files.all? { |file| file.ends_with?('.xml') }
    end

    def self.gitmodules_file?(config_files)
      config_files.first == '.gitmodules'
    end
  end
end
