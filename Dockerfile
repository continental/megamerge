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

FROM ruby:2.5

ENV INSTALL_DIR="/megamerge"

RUN set -xe \
  && apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
    build-essential \
    nodejs \
  \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p $INSTALL_DIR
WORKDIR $INSTALL_DIR

COPY src/Gemfile src/Gemfile.lock ./
RUN gem install bundler \
  && bundle install --jobs 20 --retry 5

COPY ./src ./

EXPOSE 3000
ENTRYPOINT ["bundle", "exec"]
CMD ["rails", "server", "-b", "0.0.0.0"]
