#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""
describe 'libkv::atomic_put' do
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
      def set_value(shared)
        call_function("libkv::put", shared.merge({"value" => "value3"}))
      end
      context "and when the key doesn't exist" do
        it 'should throw an exception' do
          params = {
            'key' => '/test/atomic_put/test1'
          }.merge(shared_params)
          is_expected.to run.with_params(params).and_raise_error(Exception);
	end
      end
      context "and when the key doesn't exist and previous is empty" do
        it 'should return true' do
          params = {
            'key' => '/test/atomic_put/test2'
          }.merge(shared_params)
          empty = call_function("libkv::empty_value", params)
          result = subject.execute(params.merge({'previous' => empty, 'value' => 'value2'}))
          expect(result).to eql(true)
        end
        it 'should set the key to value' do
          params = {
            'key' => '/test/atomic_put/test3'
          }.merge(shared_params)
          empty = call_function("libkv::empty_value", params)
          subject.execute(params.merge({'previous' => empty, 'value' => 'value3'}))
          result = call_function("libkv::get", params)
          expect(result).to eql("value3")
        end
      end
      context "and when the key doesn't exist and previous is random" do
        it 'should return false' do
          params = {
            'key' => '/test/atomic_put/test4'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'key' => '/test/atomic_put/test5', 'value' => 'value5'}))
          random = call_function("libkv::atomic_get", params.merge({'key' => '/test/atomic_put/test5'}))
          result = subject.execute(params.merge( { 'previous' => random, 'value' => 'value4'}))
          expect(result).to eql(false)
        end
        it 'should not set the key to value' do
          params = {
            'key' => '/test/atomic_put/test6'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'key' => '/test/atomic_put/test5', 'value' => 'value5'}))
          random = call_function("libkv::atomic_get", params.merge({'key' => '/test/atomic_put/test5'}))
          subject.execute(params.merge({'previous' => random, 'value' => 'value6'}))
          result = call_function("libkv::get", params)
          expect(result).to eql(nil)
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
       it "should return true of type #{klass} for /atomic_put/#{hash[:key]} when previous is correct" do
         params = {
             'key' => "/atomic_put/" + hash[:key],
         }.merge(shared_params)
         original = call_function("libkv::atomic_get", params)

         params = {
             'key' => "/atomic_put/" + hash[:key],
             'value' => hash[:value],
             'previous' => original,
         }.merge(shared_params)
         result = subject.execute(params)
         expect(result.to_s).to eql("true")
       end
        it "should return an object of type #{klass} for /atomic_put/#{hash[:key]}" do
          params = {
             'key' => "/atomic_put/" + hash[:key],
          }.merge(shared_params)
          original = call_function("libkv::atomic_get", params)

          params = {
             'key' => "/atomic_put/" + hash[:key],
             'value' => hash[:value],
             'previous' => original,
          }.merge(shared_params)
          subject.execute(params)
          result = call_function("libkv::atomic_get", params)
          expect(result["value"].class.to_s).to eql(klass)
        end
        it "should return '#{expected_retval}' for /atomic_put/#{hash[:key]}" do
          params = {
             'key' => "/atomic_put/" + hash[:key],
          }.merge(shared_params)
          original = call_function("libkv::atomic_get", params)

          params = {
             'key' => "/atomic_put/" + hash[:key],
             'value' => hash[:value],
             'previous' => original,
          }.merge(shared_params)
          subject.execute(params)
          result = call_function("libkv::atomic_get", params)
          expect(result["value"]).to eql(expected_retval)
        end
        unless (hash[:class] == "String")
          if (providerinfo["serialize"] == true)
            it "should create the key '/atomic_put/#{hash[:key]}.meta' and contain a type = #{hash[:puppet_type]}" do
              params = {
                'key' => "/atomic_put/" + hash[:key],
              }.merge(shared_params)
              original = call_function("libkv::atomic_get", params)

              params = {
               'key' => "/atomic_put/" + hash[:key],
               'value' => hash[:value],
               'previous' => original,
              }.merge(shared_params)
              subject.execute(params)

              params = {
               'key' => "/atomic_put/" + hash[:key] + ".meta",
              }.merge(shared_params)
              result = call_function("libkv::get", params)
              expect(result).to_not eql(nil)
              expect(result.class).to eql(String)
              attempt_to_parse = nil
              res = nil
              begin
                res = JSON.parse(result)
                attempt_to_parse = true
              rescue
                attempt_to_parse = false
              end
              expect(attempt_to_parse).to eql(true)
              expect(res.class).to eql(Hash)
              expect(res["type"]).to eql(hash[:puppet_type].to_s)
            end
          end
        end
      end
    end
  end
end
