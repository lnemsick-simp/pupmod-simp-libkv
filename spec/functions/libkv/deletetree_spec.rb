#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""

# describe 'libkv::deletetree' do
#   it 'should throw an exception with empty parameters' do
#     is_expected.to run.with_params({}).and_raise_error(Exception);
#   end
#   providers.each do |providerinfo|
#     provider = providerinfo["name"]
#     url = providerinfo["url"]
#     shared_params = {
#       "url" => url
#     }
#     context "when provider = #{provider}" do
#       context "and when the key doesn't exist" do
#         it 'should return false' do
#           params = {
#             'key' => '/deletetree/tree1'
#           }.merge(shared_params)
#           result = subject.execute(params)
#           expect(result).to eql(true)
#         end
#       end
#       context "and when just that key exists" do
#         it 'should return true' do
#           params = {
#             'key' => '/deletetree/tree1'
#           }.merge(shared_params)
#           call_function("libkv::put", params.merge({ 'key' => '/deletetree/tree2/test1', 'value' => 'value1'}))
#           call_function("libkv::put", params.merge({ 'key' => '/deletetree/tree2/test2', 'value' => 'value2'}))
#           call_function("libkv::put", params.merge({ 'key' => '/deletetree/tree2/test3', 'value' => 'value3'}))
#           call_function("libkv::put", params.merge({ 'key' => '/deletetree/tree2/test4', 'value' => 'value4'}))
#           result = subject.execute(params)
#           expect(result).to eql(true)
#         end
#         it 'should return true and delete that key'
#       end
#       context "and when child keys exist" do
#         it 'should return true'
#         it 'should return true and delete all child keys'
#       end
#     end
#   end
# end
