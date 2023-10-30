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

module CoreExtensions
  module Object
    # Global file lock
    module Flock
      include Loggable
      def with_flock(name = 'global', blocking = true, dir = '/tmp/mm/locks/', logging = true)
        lock_file = dir + name.gsub(/[^0-9A-Za-z]/, '_') + '.lock' # replace all special chars by _
        FileUtils.mkdir_p(dir) unless File.exists?(dir)
        file_lock = File.open(lock_file, File::RDWR | File::CREAT, 0o644)
        ret = file_lock.flock(File::LOCK_EX | File::LOCK_NB)  unless blocking
        ret = file_lock.flock(File::LOCK_EX)  if blocking
        got_lock = ret == 0
        #logger.info "wait blocking: #{blocking} ,  ret: #{ret}, got_lock : #{got_lock}"

        logger.info "lock denied on #{lock_file}" unless got_lock
        return unless got_lock

        logger.info "locking on #{lock_file}" if logging
        yield
      ensure
        if !file_lock.nil? && got_lock
          logger.info "unlocking #{lock_file}" if logging
          file_lock.flock(File::LOCK_UN)
        end
      end

    end
  end
end
