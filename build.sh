#!/bin/bash

git rev-parse HEAD > ./src/revision.txt
docker build ./ --tag iip-docker.buic-scm-wet.contiwan.com/megamerge/local_build
docker push iip-docker.buic-scm-wet.contiwan.com/megamerge/local_build