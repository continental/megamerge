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

FROM ubuntu:18.04
RUN set -xe \
  && apt-get update \
  && apt-get install software-properties-common --no-install-recommends --no-install-suggests -y
  
RUN apt-add-repository ppa:brightbox/ruby-ng -y

RUN set -xe \
  && apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
  software-properties-common \
  ruby2.7 \
  ruby2.7-dev \
  ruby-bundler \
  build-essential \
  zlib1g-dev \
  nodejs \
  git \
  libffi-dev \
  libpq-dev \
  \
  && gem install bundler -v 1.16.1\
  \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
  
ARG user=megamerge
ARG group=megamerge
ARG uid=1000
ARG gid=1000

RUN groupadd -g ${gid} ${group}
RUN useradd -c "Megamerge user" -d /home/${user} -u ${uid} -g ${gid} -m ${user}  

WORKDIR /srv
COPY ./src/Gemfile /srv/Gemfile
COPY ./src/Gemfile.lock /srv/Gemfile.lock

RUN bundle install

COPY ./src /srv/

RUN chown -R ${user}: /srv
USER ${user}

RUN bundle exec rake assets:precompile

EXPOSE 3000
CMD ["/usr/local/bin/rails", "server", "-b", "0.0.0.0"]
