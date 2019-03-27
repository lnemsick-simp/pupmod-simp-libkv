#!/bin/sh
bundle install --path=vendor
rpath="$(dirname $(dirname $0))/spec/fixtures/modules"
mkdir spec/fixtures/modules
ln -s . spec/fixtures/modules/libkv
bundle exec puppet apply --modulepath=${rpath} -e 'class {"libkv::test": url => "consul://172.17.0.1:8500/puppet" }'
