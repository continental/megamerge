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
  # Parses the meta repository's mega merge state out of a pull request body
  # Format:
  #   Pull Request Body
  #   <!-- BEGIN MEGAMERGE -->
  #   <!-- version 1.2.3 -->
  #   <!-- configuration: {json} -->
  #   Mega merge specific body
  #   <!-- END MEGAMERGE -->
  class Decoder
    CONFIG = /<!-- configuration: (.*) -->/
    VERSION = /<!-- version: (.*) -->/

    attr_reader :text

    def self.decode(text)
      new(text).decode
    end

    def initialize(text)
      @text = text
    end

    def decode
      return nil unless valid?
      {
        body: body,
        config: config
      }
    end

    protected

    def valid?
      !text.nil? && valid_structure? && valid_version? && valid_config? && valid_type?
    end

    def structure
      @structure ||= text.match(/(.*)#{ Encoder::HEADER }(.*)#{ Encoder::FOOTER }/m)
    end

    def valid_structure?
      structure && structure.captures.size == 2
    end

    def version
      @version ||= Version.new(text.match(VERSION)&.[](1))
    end

    def valid_version?
      version.major == Encoder::CONFIG_VERSION.major
    end

    def config
      @config ||= JSON.parse(text.match(CONFIG)&.[](1).to_s)&.symbolize_keys
    rescue JSON::ParseError
      nil
    end

    def valid_config?
      config.present?
    end

    def valid_type?
      config[:type] == Encoder::PARENT_TYPE ||
        config[:type] == Encoder::CHILD_TYPE
    end

    def body
      @body ||= structure[1]
    end
  end
end
