#!/bin/bash -ex
RBENV_VERSION=2.6.9 bundle exec rake spec
RBENV_VERSION=2.7.0 bundle exec rake spec
RBENV_VERSION=2.7.2 bundle exec rake spec
RBENV_VERSION=2.7.3 bundle exec rake spec
RBENV_VERSION=2.7.5 bundle exec rake spec
RBENV_VERSION=3.0.0 bundle exec rake spec
RBENV_VERSION=3.0.3 bundle exec rake spec
RBENV_VERSION=3.1.0 bundle exec rake spec
RBENV_VERSION=3.2.0-dev bundle exec rake spec
