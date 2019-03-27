#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""

describe 'libkv::atomic_get' do
  it 'should throw an exception with empty parameters' do
    is_expected.to run.with_params({}).and_raise_error(Exception);
  end
  providers.each do |providerinfo|
    provider = providerinfo["name"]
    url = providerinfo["url"]
    auth = providerinfo["auth"]
    shared_params = {
      "url" => url,
      "serialize" => providerinfo["serialize"],
      "mode" => providerinfo["mode"],
      "auth" => auth,
    }
    context "when provider = #{provider}" do
      context "when the key 'test3' exists" do
        def set_value(shared)
          call_function("libkv::put", shared.merge({"value" => "value3"}))
        end
        it 'should return a hash' do
          params = {
            'key' => '/test3'
          }.merge(shared_params)
          set_value(params)
          result = subject.execute(params)
          expect(result.class).to eql(Hash)
        end
        it 'should return a hash with more then one element' do
          params = {
            'key' => '/test3'
          }.merge(shared_params)
          set_value(params)
          result = subject.execute(params)
          expect(result.size).to be > 1
        end
        it 'should return a hash with a "value" key' do
          params = {
            'key' => '/test3'
          }.merge(shared_params)
          set_value(params)
          result = subject.execute(params)
          expect(result.key?("value")).to eql(true)
        end
        it 'should return a hash with a "value" key containing a "test" value' do
          params = {
            'key' => '/test3'
          }.merge(shared_params)
          set_value(params)
          result = subject.execute(params)
          expect(result["value"]).to eql("value3")
        end
      end
      context "when the key 'test4' doesn't exist" do
        it 'should return a hash' do
          params = {
            'key' => '/test4'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result.class).to eql(Hash)
        end
        it 'should return a hash with at least one element' do
          params = {
            'key' => '/test4'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result.size).to be > 1
        end
        it 'should return a hash with a "value" key' do
          params = {
            'key' => '/test4'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result.key?("value")).to eql(true)
        end
        it 'should return a hash with a "value" key containing a nil value' do
          params = {
            'key' => '/test4'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result["value"]).to eql(nil)
        end
      end
      datatype_testspec.each do |hash|
       if (providerinfo["serialize"] == true)
         klass = hash[:class]
       else
         klass = hash[:nonserial_class]
       end
       if (providerinfo["serialize"] == true)
         expected_retval = hash[:value]
       else
         expected_retval = hash[:nonserial_retval]
       end
        it "should return an object of type #{klass} for /atomic_get/#{hash[:key]}" do
          params = {
             'key' => "/atomic_get/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          call_function("libkv::put", params)

          params = {
             'key' => "/atomic_get/" + hash[:key],
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result["value"].class.to_s).to eql(klass)
        end
        it "should return '#{hash[:value]}' for /atomic_get/#{hash[:key]}" do
          params = {
             'key' => "/atomic_get/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          call_function("libkv::put", params)

          params = {
             'key' => "/atomic_get/" + hash[:key],
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result["value"]).to eql(expected_retval)
        end
      end

    end
  end
end
