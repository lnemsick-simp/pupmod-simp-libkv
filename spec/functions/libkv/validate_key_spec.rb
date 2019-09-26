require 'spec_helper'

describe 'libkv::validate_key' do

  context 'valid keys' do
    [
      'simple',
      'looks/like/a/file/path',
      'looks/like/a/directory/path/',
      'simp-simp_snmpd:password.auth',
      'this/.../technically/is/ok'
    ].each do |key|
      it "should allow key='#{key}'" do
        is_expected.to run.with_params(key)
      end
    end
  end

  context 'invalid keys' do
    # Character tests below are not exhaustive! Just spot checks with US
    # keyboard special chars.
    [
      ' ', "\t", "\r", "\n"
    ].each do |ws_char|
      it "should fail when key contains whitespace character #{ws_char.inspect}" do
        key = 'key' + ws_char
        is_expected.to run.with_params(key).and_raise_error(ArgumentError,
          /key '#{Regexp.escape(key)}' contains disallowed whitespace/)
      end
    end

    [ '~', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '+', '`', '=',
      '{', '}', '[', ']', '|', '\\', ';', "'", '"', '<', '>', ',', '?'
    ].each do |bad_char|
      it "should fail when key contains disallowed special character '#{bad_char}'" do
        key = 'key' + bad_char
        is_expected.to run.with_params(key).and_raise_error(ArgumentError,
          /key '#{Regexp.escape(key)}' contains unsupported characters/)
      end
    end

    it 'should fail when key contains disallowed /./ sequence' do
      key = 'looks/like/an/./unexpanded/linux/path'
      is_expected.to run.with_params(key).and_raise_error(ArgumentError,
        /key '#{Regexp.escape(key)}' contains disallowed '\/\.\/' or '\/\.\.\/' sequence/)
    end

    it 'should fail when key contains disallowed /../ sequence' do
      key = 'looks/like/another/../unexpanded/linux/path'
      is_expected.to run.with_params(key).and_raise_error(ArgumentError,
        /key '#{Regexp.escape(key)}' contains disallowed '\/\.\/' or '\/\.\.\/' sequence/)
    end
  end

end
