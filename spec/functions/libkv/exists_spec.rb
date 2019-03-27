#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""

describe 'libkv::exists' do
  providers.each do |providerinfo|
    provider = providerinfo["name"]
    url = providerinfo["url"]
    auth = providerinfo["auth"]
    shared_params = {
      "url" => url,
      "auth" => auth,
    }
    context "when provider = #{provider}" do
      context "when the key exists" do
        it 'should return true' do
          params = {
            'key' => '/test7'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({ 'key' => '/test7', 'value' => 'value7'}))
          result = subject.execute(params)
          expect(result).to eql(true)
        end
      end
      context "when the key doesn't exist" do
        it 'should return false' do
          params = {
            'key' => '/test8'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result).to eql(false)
        end
      end
    end
  end
end
