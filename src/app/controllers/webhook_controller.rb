# frozen_string_literal: true

# Copyright (c) 2021 Continental Automotive GmbH
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

class WebhookController < ApplicationController
  skip_before_action :require_login
  skip_before_action :verify_authenticity_token

  def event
    RequestStore.store[:is_webhook] = true
    ProcessGitHubEvent.call(request.headers['X-GitHub-Event'], params)
    render plain: RequestStore.store[:log]
  end
end
