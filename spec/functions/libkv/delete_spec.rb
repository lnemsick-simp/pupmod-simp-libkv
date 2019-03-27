#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""


describe 'libkv::delete' do
  it 'should throw an exception with empty parameters' do
    is_expected.to run.with_params({}).and_raise_error(Exception);
  end
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
            'key' => '/test5'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({ 'key' => '/test5', 'value' => 'value5'}))
          result = subject.execute(params)
          expect(result).to eql(true)
        end
        it 'should remove the key' do
          params = {
            'key' => '/test5'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({ 'key' => '/test5', 'value' => 'value5'}))
          call_function("libkv::delete", params.merge({ 'key' => '/test5'}))
          result = call_function("libkv::exists", params.merge({ 'key' => '/test5'}))
          expect(result).to eql(false)
        end
        it 'should remove the metadata value' do
          params = {
            'key' => '/test5'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({ 'key' => '/test5', 'value' => 'value5'}))
          call_function("libkv::delete", params.merge({ 'key' => '/test5'}))
          result = call_function("libkv::exists", params.merge({ 'key' => '/test5.meta'}))
          expect(result).to eql(false)
        end
      end
      context "when the key doesn't exist" do
        it 'should return true' do
          params = {
            'key' => '/test6'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result).to eql(true)
        end
      end
    end
  end
end
