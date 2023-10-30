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


class IpcStore

    BASEPATH ||= "/tmp/mm/"
  

    def initialize(category)
        @category = category
        FileUtils.mkdir_p(folder) unless File.exists?(folder)
    end

    def folder
        BASEPATH + @category + '/'
    end 

    # returns all events in folder and subfolders ordered by last time modified (oldest frist)
    def list
        Dir.glob(folder + "**/*.ipc").sort_by { |x| File.mtime(x) }.map{ |encoded_filename| decode(encoded_filename)}
    end

    def add(subcategory, name)
        encoded = filename_encode(name)
        raise "string #{name} is too long (encoded limit = 255)" if encoded.length >= 255
        FileUtils.mkdir_p(folder + subcategory) unless File.exists?(folder + subcategory)
        File.write(folder + subcategory + '/' + filename_encode(name), "")
    end

    def delete(subcategory, name)
        begin
            #logger.info "deleting #{folder + subcategory + '/' + filename_encode(name)}"
            File.delete(folder + subcategory + '/' + filename_encode(name))
        rescue StandardError => e
        end
    end

    def size
        list.size
    end


    def filename_encode(name)
        Base64.strict_encode64(name) + ".ipc"
    end

    def decode(data)
        subcategory = (File.dirname(data) + '/').gsub(folder,'').gsub('/','') 
        name = filename_decode(File.basename(data, ".*"))
        return subcategory, name
    end

    def filename_decode(encoded_name)
        Base64.decode64(encoded_name)
    end


end

  