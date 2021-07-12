#!/bin/bash -ex
RBENV_VERSION=2.6.4 bundle exec rake spec
RBENV_VERSION=2.7.0 bundle exec rake spec
RBENV_VERSION=2.7.2 bundle exec rake spec
RBENV_VERSION=3.0.1 bundle exec rake spec
RBENV_VERSION=3.1.0-dev bundle exec rake spec
