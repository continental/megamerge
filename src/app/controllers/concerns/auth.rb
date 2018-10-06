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

require_dependency 'git_hub/user'

module Auth
  def process_login
    return unless request[:code]
    logger.info 'OAuth Authorization: ' + request[:code]
    session[:access_token] = GitHub::User.token(request[:code])
  end

  def require_login
    # TODO: Add authorzation regarding organization
    logger.info "Verify Authorization: #{session[:access_token]}"
    return render 'session/index' unless session[:access_token]
    @user = GitHub::User.new(session[:access_token])
  rescue StandardError
    logger.info 'Invalidating access_token'
    session.delete(:access_token)
    render 'session/index'
  end
end
