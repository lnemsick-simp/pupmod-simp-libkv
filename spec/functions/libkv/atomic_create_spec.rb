#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@\#$%^&*()\""

describe 'libkv::atomic_create' do
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
      it 'should throw an exception when "key" is missing' do
        is_expected.to run.with_params(shared_params).and_raise_error(Exception)
      end
      it 'should throw an exception when "value" is missing' do
        is_expected.to run.with_params(shared_params.merge({"key" => "/test1"})).and_raise_error(Exception)
      end
      it 'should return a Boolean' do
        params = {
          'key' => '/test1',
          'value' => 'value1',
        }.merge(shared_params)
        result = subject.execute(params)
        expect(result.class).to eql(TrueClass)
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
        it "should create an object of type #{klass} for /put/#{hash[:key]}" do
          params = {
             'key' => "/put/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          subject.execute(params)

          params = {
             'key' => "/put/" + hash[:key],
          }.merge(shared_params)
          result = call_function("libkv::get", params)
          expect(result.class.to_s).to eql(klass)
        end
        it "should create the value '#{hash[:value]}' for /put/#{hash[:key]}" do
          params = {
             'key' => "/put/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          subject.execute(params)

          params = {
             'key' => "/put/" + hash[:key],
          }.merge(shared_params)
          result = call_function("libkv::get", params)
          expect(result).to eql(expected_retval)
        end
        unless (hash[:class] == "String")
          if (providerinfo["serialize"] == true)
            it "should create the key '/put/#{hash[:key]}.meta' and contain a type = #{hash[:puppet_type]}" do
              params = {
               'key' => "/put/" + hash[:key],
                'value' => hash[:value],
              }.merge(shared_params)
              subject.execute(params)

              params = {
                 'key' => "/put/" + hash[:key] + ".meta",
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
