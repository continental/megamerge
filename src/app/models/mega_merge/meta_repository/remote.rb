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
    # Remotes for super repository
    class Remote < BaseModel
      attr_accessor :name, :server
      attr_reader :uri

      # default server
      def self.default_server
        Addressable::URI.parse(Rails.application.config.github[:server])
      end

      def organization
        uri.path.sub(/^\//, '')
      end

      def uri=(value)
        if value =~ /(\w+)@(.*):(.*)/
          result = value.match(/(\w+)@(.*):(.*)/).captures
          # set the uri value of the remote structure
          # HACK: remove me
          @uri = Addressable::URI.parse('ssh://' + result[0] + '@' + result[1] + '/' + result[2])
        else
          @uri = Addressable::URI.parse(value)
        end
      end

      def valid?
        uri && !uri.host.match(self.class.default_server.host).nil?
      end
    end
  end
end
