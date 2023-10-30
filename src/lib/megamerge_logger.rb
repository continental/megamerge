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
class MegamergeLogger < Logger

  def initialize(*args)
    @api_count = 0
    @api_runtime = 0
    super(*args)
  end

  def info(progname = nil, &block)
    customadd(INFO, nil, progname)
  end

  def warn(progname = nil, &block)
    customadd(WARN, nil, progname)
  end

  def error(progname = nil, &block)
    customadd(ERROR, nil, progname)
  end

  def fatal(progname = nil, &block)
    customadd(FATAL, nil, progname)
  end

  def customadd(severity, message = nil, progname = nil)
    store_message("\n" + progname) unless progname.nil? || progname.empty?

    if progname[0, 35].include?("method=") # print logs after each request
      time = Time.now.strftime("%H:%M:%S.%L")
      api_stats = update_api_call_stats
      final_message = "\n#{time} \tAPI Calls: #{@api_count}, #{@api_runtime.round(2)} sec \t Sum: (#{api_stats[:counter]}, #{api_stats[:runtime].round(2)} sec) #{@msg_store}\n"
      add(severity, message, final_message)  
      puts final_message 
      reset_store
    end
  end

  def print(msg)
    store_message(msg)
  end



  def reset_store
    @msg_store = ""
    @api_count = 0
    @api_runtime = 0
  end
 
  # reset all stats to 0 if reset timer has expired, then increase as needed
  def update_api_call_stats
    return {:counter => 0, :runtime => 0 } if @api_count == 0 && @api_runtime == 0
    Rails.cache.fetch(
      "api_stat_reset_timer",
      expires_in: 1.minute
    ) do
      Rails.cache.write("api_stat_counter", 0)
      Rails.cache.write("api_stat_runtime", 0)
      0
    end

    {
      :counter => Rails.cache.increment("api_stat_counter", @api_count),
      :runtime => Rails.cache.increment("api_stat_runtime", @api_runtime * 100) / 100
    }
  end


  def store_message(msg)
    if @msg_store.nil? 
      @msg_store = msg
    else
      @msg_store += msg 
    end
  end
  


  def api_call(runtime)
    @api_count+=1
    @api_runtime+=runtime
  end
end

