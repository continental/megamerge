# frozen_string_literal: true

# Copyright (c) 2022 Continental Automotive GmbH
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
#
class LogDeleteJob < ActiveJob::Base
  def perform
    reschedule_job

    do_work
  end

  def do_work
    #delete files older than 7 days
    Dir["logs/*"].select{|f| File.mtime(f) < (Time.now - (60*60*24*7)) }.each{|f|
      begin
        File.delete(f)
      rescue Errno::ENOENT
      end
    }
  end

  def reschedule_job
    self.class.set(wait: 24.hour).perform_later
  end
end
