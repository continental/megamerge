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

FROM ubuntu:16.04

RUN set -xe \
  && apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
    ruby \
    ruby-dev \
    ruby-bundler \
    build-essential \
    zlib1g-dev \
    libsqlite3-dev \
    nodejs \
    git \
    libffi-dev \
  \
  && gem install \
    bundler \
  \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./src/Gemfile /tmp
WORKDIR /tmp
RUN bundle install

COPY ./src /srv/
WORKDIR /srv/
RUN bundle install

EXPOSE 3000
CMD ["/usr/local/bin/rails", "server", "-b", "0.0.0.0"]
