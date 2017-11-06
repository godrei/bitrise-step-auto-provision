#!/bin/bash

export build_api_token='3-B-dLT-VgqI12hBDmPfkA'
export build_url='http://192.168.0.234:3000/build/08cfcc5afee8b747'
export team_id='339CX9E66J'

# set -ex
# curl -i -H "BUILD_API_TOKEN: $build_api_token" -X GET "$build_url/apple_developer_portal_data"
# exit 1

export certificate_urls="file://$HOME/Documents/Időpont/AppStoreCertificates.p12|file://$HOME/Documents/Időpont/DevelopmentCertificates.p12"
# export certificate_urls="https://concrete-userfiles-production.s3-us-west-2.amazonaws.com/build_certificates/uploads/22417/original/DevelopmentCertificates.p12?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOC7N256G7J2W2TQ%2F20171103%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20171103T094355Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=9dc3380808bb6ce04a5c7074b7a20f28f49441eed9be7b0ce7aee5e0d7a0a438|https://concrete-userfiles-production.s3-us-west-2.amazonaws.com/build_certificates/uploads/21525/original/AppStoreCertificates.p12?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOC7N256G7J2W2TQ%2F20171103%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20171103T094355Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=92920378771813d0afb75b9a886aa57fb9d1fa7597db7f2e4bac0b04e4354c83"
export certificate_passphrases="|"
export distributon_type="app-store"
export project_path="$HOME/Develop/ios/code-sign-test/code-sign-test.xcodeproj"

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