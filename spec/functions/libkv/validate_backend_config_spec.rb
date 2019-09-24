require 'spec_helper'

describe 'libkv::validate_backend_config' do

  let(:backends) { [ 'file' ] }

  context 'valid backend config' do

    it 'should allow valid config' do
      config = {
        'backend'     => 'test_file',
        'environment' => 'production',
        'backends'    => {
          'test_file'  => {
            'id'        => 'test',
            'type'      => 'file'
          },
          'another_file' => {
            'id'        => 'another_test',
            'type'      => 'file'
          },
          'consul_1' => {
            'id'        => 'primary',
            'type'      => 'consul'
          },
          'consul_2' => {
            'id'        => 'secondary',
            'type'      => 'consul'
          }
        }
      }

      is_expected.to run.with_params(config, backends)
    end
  end

  context 'invalid backend config' do
    it "should fail when options is missing 'backend'" do
      options = {}
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /'backend' not specified in libkv configuration/)
    end

    it "should fail when options is missing 'backends'" do
      options = { 'backend' => 'file' }
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /'backends' not specified in libkv configuration/)
    end

    it "should fail when 'backends' in not a Hash" do
      options = { 'backend' => 'file', 'backends' => [] }
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /'backends' in libkv configuration is not a Hash/)
    end

    it "should fail when 'backends' does not have an entry for 'backend'" do
      options = { 'backend' => 'file', 'backends' => {} }
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /No libkv backend 'file' with 'id' and 'type' attributes has been configured/)
    end

    it "should fail when 'backends' entry for 'backend' is not a Hash" do
      options = { 'backend' => 'file', 'backends' => { 'file' => [] } }
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /No libkv backend 'file' with 'id' and 'type' attributes has been configured/)
    end

    it "should fail when 'backends' entry for 'backend' is missing 'id'" do
      options = { 'backend' => 'file', 'backends' => { 'file' => {} } }
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /No libkv backend 'file' with 'id' and 'type' attributes has been configured/)
    end

    it "should fail when 'backends' entry for 'backend' is missing 'type'" do
      options = { 'backend' => 'file', 'backends' => { 'file' => { 'id' => 'test'} } }
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /No libkv backend 'file' with 'id' and 'type' attributes has been configured/)
    end

    it "should fail when the plugin for 'backend' has not been loaded" do
      options = {
        'backend'  => 'file',
        'backends' => { 'file' => { 'id' => 'test', 'type' => 'file'} }
      }
      is_expected.to run.with_params(options, [ 'consul' ]).
        and_raise_error(RuntimeError,
        /libkv backend plugin 'file' not available/)
    end

    it "should fail when 'backends' does not specify unique plugin instances" do
      options = {
        'backend'  => 'file1',
        'backends' => {
          'file1'     => { 'id' => 'test', 'type' => 'file'},
          'file1_dup' => { 'id' => 'test', 'type' => 'file', 'foo' => 'bar'}
         }
      }
      is_expected.to run.with_params(options, backends).
        and_raise_error(RuntimeError,
        /libkv config contains multiple backend configs for type=file id=test/)
    end

  end

end