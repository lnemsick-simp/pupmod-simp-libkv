#!/usr/bin/env ruby
#
# vim: set expandtab ts=2 sw=2:
require 'erb'
template = File.read('./readme.erb');
renderer = ERB.new(template, nil, '-')
require 'yaml'
data = YAML.load_file('data.yaml')

b = binding;
b.local_variable_set(:data, data)
result = renderer.result(b);
File.write('../README.md', result)
