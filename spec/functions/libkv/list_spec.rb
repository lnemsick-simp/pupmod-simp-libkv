#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""

describe 'libkv::list' do
  it 'should throw an exception with empty parameters' do
    is_expected.to run.with_params({}).and_raise_error(Exception);
  end
  providers.each do |providerinfo|
    provider = providerinfo["name"]
    url = providerinfo["url"]
    auth = providerinfo["auth"]
    serialize = providerinfo["serialize"]
    shared_params = {
      "url" => url,
      "auth" => auth,
      "serialize" => serialize,
    }
    context "when provider = #{provider}" do
      context "when the key doesn't exist" do
        it 'should return a hash' do
          params = {
            'key' => '/test9'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result.class).to eql(Hash)
        end
        it 'should return an empty hash' do
          params = {
            'key' => '/test9'
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result).to eql({})
        end
      end
      context "and when the key exists" do
        def set_value(shared)
          call_function("libkv::put", shared.merge({"value" => "value3"}))
        end
        it 'should return a hash' do
          params = {
            'key' => '/test10'
          }.merge(shared_params)
          set_value(params.merge({'key' => '/test10/test1', 'value' => 'value10'}))
          set_value(params.merge({'key' => '/test10/test2', 'value' => 'value10'}))
          result = subject.execute(params)
          expect(result.class).to eql(Hash)
        end
        it 'should return a hash of strings' do
          params = {
            'key' => '/test10'
          }.merge(shared_params)
          set_value(params.merge({'key' => '/test10/test1', 'value' => 'value10'}))
          set_value(params.merge({'key' => '/test10/test2', 'value' => 'value10'}))
          result = subject.execute(params)
          found_non_string = false
          result.keys.each do |key|
            if (key.class != String)
              found_non_string = true
            end
          end
          expect(found_non_string).to eql(false)
        end
        it 'when passed "fruits" it should return "apple" and "banana"' do
          params = {
            'key' => '/test11/fruits'
          }.merge(shared_params)

          set_value(params.merge({'key' => '/test11/fruits/apple', 'value' => 'value11'}))
          set_value(params.merge({'key' => '/test11/fruits/banana', 'value' => 'value11'}))
          set_value(params.merge({'key' => '/test11/meats/beef', 'value' => 'value11'}))
          set_value(params.merge({'key' => '/test11/meats/pork', 'value' => 'value11'}))

          result = subject.execute(params);
          contains = result.key?("apple") and result.key?("banana");
          expect(contains).to eql(true)
        end
        it 'when passed "meats" it should return "beef" and "pork"' do
          params = {
            'key' => '/test12/meats'
          }.merge(shared_params)

          set_value(params.merge({'key' => '/test12/fruits/apple', 'value' => 'value12'}))
          set_value(params.merge({'key' => '/test12/fruits/banana', 'value' => 'value12'}))
          set_value(params.merge({'key' => '/test12/meats/beef', 'value' => 'value12'}))
          set_value(params.merge({'key' => '/test12/meats/pork', 'value' => 'value12'}))

          result = subject.execute(params);
          contains = result.key?("beef") and result.key?("pork");
          expect(contains).to eql(true)
        end
        it 'when passed "/test/list/fire" it should return "fox" and "starter" and not "/test/list/fire2/big" or "/test/list/fire2/water"' do
          params = {
            'key' => '/test/list/fire'
          }.merge(shared_params)

          set_value(params.merge({'key' => '/test/list/fire/fox', 'value' => 'value12'}))
          set_value(params.merge({'key' => '/test/list/fire/starter', 'value' => 'value12'}))
          set_value(params.merge({'key' => '/test/list/fire2/water', 'value' => 'value12'}))
          set_value(params.merge({'key' => '/test/list/fire2/big', 'value' => 'value12'}))

          result = subject.execute(params);
          contains = result.key?("fox") and result.key?("starter");
          size = result.size;
          expect(contains).to eql(true)
          expect(size).to eql(2)
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
        it "should return an object of type #{klass} for /list/#{hash[:key]}" do
          params = {
             'key' => "/list/" + hash[:key] + "/value",
             'value' => hash[:value],
          }.merge(shared_params)
          call_function("libkv::put", params)

          params = {
             'key' => "/list/" + hash[:key],
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result["value"].class.to_s).to eql(klass)
        end
        it "should return '#{hash[:value]}' for /list/#{hash[:key]}" do
          params = {
             'key' => "/list/" + hash[:key] + "/value",
             'value' => hash[:value],
          }.merge(shared_params)
          call_function("libkv::put", params)

          params = {
             'key' => "/list/" + hash[:key],
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result["value"]).to eql(expected_retval)
        end
      end
    end
  end
end
