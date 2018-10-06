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

class SessionController < ApplicationController
  skip_before_action :require_login, only: [:oauth]

  def index
    @revision = `git rev-parse HEAD` || 'unknown'
    redirect_to(step1_path) if session[:access_token]
  end

  def oauth
    process_login
    redirect_to step1_path
  end

  def logout
    session.delete(:access_token)
  end
end
