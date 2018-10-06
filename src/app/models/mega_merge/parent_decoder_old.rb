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

# decoder module to parse megamerge meta data before version 3.0
module MegaMerge
  # Parses the meta repository's mega merge state out of a pull request body
  # Format:
  #   Pull Request Body
  #   <!-- BEGIN MEGAMERGE -->
  #   <!-- configuration: config_file source_branch squash -->
  #   * org/repo#prId
  #   <!-- END MEGAMERGE -->
  class ParentDecoderOld < Decoder
    def valid_type?
      config[:type] == Encoder::PARENT_TYPE
    end

    def valid_version?
      true
    end

    def config
      metaconfig = structure[2].match(/<!-- configuration: (.*) (.*) (.*) -->/)
      return nil if metaconfig.nil? || metaconfig.captures[0..-2].any?(&:empty?)
      config = {
        squash: (metaconfig[3] == 'true' || metaconfig[3].empty?),
        source_branch: metaconfig[2],
        config_file: metaconfig[1],
        type: Encoder::PARENT_TYPE
      }
      config[:children] = []
      structure[2].each_line do |line|
        link = line.match(/([^\/ ]+)\/([^\/ #]+)#(\d+)(.*)/)

        if link && link[1] && link[2] && link[3]
          config[:children].push(id: link[3].to_i, name: link[1] + '/' + link[2])
        end
      end

      config
    end
  end
end
