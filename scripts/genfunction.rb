#!/usr/bin/env ruby
#
# vim: set expandtab ts=2 sw=2:
require 'erb'
template = File.read('./function.erb');
renderer = ERB.new(template, nil, '-')
require 'yaml'
data = YAML.load_file('data.yaml')

data['functions'].each do |function, value|
  unless (value[:reserved] or value[:unsupported])
    b = binding;
    b.local_variable_set(:function, function);
    b.local_variable_set(:value, value);
    result = renderer.result(b);
    File.write("../lib/puppet/functions/libkv/#{function}.rb", result)
  end
end
