#!/bin/bash
# worker_build_params['abort-check-url']: http://192.168.33.37:3001/build/10d4a770af398304/abort-check.json?api_token=1LAeWBdlUFZwjNph-Hf3Ng

export build_api_token='1LAeWBdlUFZwjNph-Hf3Ng'
export build_url='http://192.168.0.234:3000/build/10d4a770af398304'
export team_id='339CX9E66J'
# curl -i -H "BUILD_API_TOKEN: $build_api_token" -X GET "$build_url/apple_developer_portal_data"

export certificate_urls="file://$HOME/Downloads/Idopontapp_App_Store_Profile.mobileprovision|file://$HOME/Downloads/Idopontapp_Development_Profile.mobileprovision"
export certificate_passphrases="|"
export distributon_type="app-store"
export project_path="$HOME/Develop/ios/code-sign-test/code-sign-test.xcodeproj"

ruby step.rb

exit 1

set -e
THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export BUNDLE_GEMFILE="$THIS_SCRIPT_DIR/Gemfile"

set +e
out=$(bundle install)
if [ $? != 0 ]; then
    echo "bundle install failed"
    echo $out
    exit 1
fi
set -e

bundle exec ruby "$THIS_SCRIPT_DIR/step.rb"