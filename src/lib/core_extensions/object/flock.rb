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
      def with_flock(lock_file = '/tmp/global.lock')
        file_lock = File.open(lock_file, File::RDWR | File::CREAT, 0o644)
        file_lock.flock(File::LOCK_EX)
        yield
      ensure
        file_lock.flock(File::LOCK_UN)
      end
    end
  end
end
