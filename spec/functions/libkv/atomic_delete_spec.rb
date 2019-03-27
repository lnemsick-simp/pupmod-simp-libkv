#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@\#$%^&*()\""

describe 'libkv::atomic_delete' do
  it 'should throw an exception with empty parameters' do
    is_expected.to run.with_params({}).and_raise_error(Exception);
  end
  providers.each do |providerinfo|
    provider = providerinfo["name"]
    url = providerinfo["url"]
    softfail = providerinfo["softfail"]
    should_error = providerinfo["should_error"]
    auth = providerinfo["auth"]
    shared_params = {
      "url" => url,
      "softfail" => softfail,
      "auth" => auth,
    }
    context "when provider = #{provider}" do
      def set_value(shared)
        call_function("libkv::put", shared.merge({"value" => "value3"}))
      end
      context "when previous is nil" do
        it 'should throw an exception' do
          params = {
            'key' => '/test/atomic_delete/test1'
          }.merge(shared_params)
          is_expected.to run.with_params(params).and_raise_error(Exception);
        end
      end
      context "and when the key doesn't exist and previous is empty" do
        it 'should return true' do
          params = {
            'key' => '/test/atomic_delete/test2'
          }.merge(shared_params)
          empty = call_function("libkv::empty_value", params)
          result = subject.execute(params.merge({'previous' => empty}))
          expect(result).to eql(true)
        end
      end
      context "and when the key does exist but previous is wrong" do
        it 'should return false' do
          params = {
            'key' => '/test/atomic_delete/test4'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'key' => '/test/atomic_delete/test3', 'value' => 'value3'}))
          call_function("libkv::put", params.merge({'value' => 'value4'}))
          random = call_function("libkv::atomic_get", params.merge({'key' => '/test/atomic_delete/test3'}))
          result = subject.execute(params.merge({'previous' => random}))
          expect(result).to eql(false)
        end
        it 'should return false and the key should not be deleted' do
          params = {
            'key' => '/test/atomic_delete/test4'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'key' => '/test/atomic_delete/test3', 'value' => 'value3'}))
          call_function("libkv::put", params.merge({'value' => 'value4'}))
          random = call_function("libkv::atomic_get", params.merge({'key' => '/test/atomic_delete/test3'}))
          result = subject.execute(params.merge({'previous' => random}))
          dataresult = call_function("libkv::get", params)
          expect(result).to eql(false)
          expect(dataresult).to eql("value4")
        end
      end
      context "and when the key does exist and previous is right" do
        it 'should return true' do
          params = {
            'key' => '/test/atomic_delete/test5'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'value' => 'value5'}))
          previous = call_function("libkv::atomic_get", params.merge({'key' => '/test/atomic_delete/test5'}))
          result = subject.execute(params.merge({'previous' => previous}))
          expect(result).to eql(true)
        end
        it 'should return true and the key should be deleted' do
          params = {
            'key' => '/test/atomic_delete/test6'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'value' => 'value5'}))
          previous = call_function("libkv::atomic_get", params.merge({}))
          subject.execute(params.merge({'previous' => previous}))
          result = call_function("libkv::atomic_get", params)
          expect(result).to eql(call_function("libkv::empty_value", params))
        end
        it 'should return true and the metadata key should be deleted' do
          params = {
            'key' => '/test/atomic_delete/test6'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'value' => 'value5'}))
          previous = call_function("libkv::atomic_get", params.merge({}))
          subject.execute(params.merge({'previous' => previous}))
          metadata_key = "#{params['key']}.meta"
          result = call_function("libkv::atomic_get", params.merge({"key" => metadata_key}))
          expect(result).to eql(call_function("libkv::empty_value", params))
        end
      end
    end
  end
end
