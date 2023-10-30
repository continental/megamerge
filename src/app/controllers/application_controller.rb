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

class ApplicationController < ActionController::Base
  include Auth

  add_flash_types :success, :warning, :danger, :info
  protect_from_forgery with: :exception
  before_action :require_login, :eager_load!

  # load the whole app in dev mode because the autoloader is not thread safe. In prod this should already have happened automatically
  # a reload is required every request because we might have changed a file
  def eager_load!
    Rails.application.eager_load! if Rails.env.development?
  end
end
