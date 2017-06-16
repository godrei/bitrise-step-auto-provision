#!/bin/bash
set -ex
THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export BUNDLE_GEMFILE="$THIS_SCRIPT_DIR/Gemfile"

bundle install
bundle exec ruby "$THIS_SCRIPT_DIR/step.rb"