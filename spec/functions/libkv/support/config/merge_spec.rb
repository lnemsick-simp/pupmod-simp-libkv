require 'spec_helper'

describe 'libkv::support::config::merge' do

  let(:backends) { [ 'file' ] }

  context 'libkv::options and app_id not specified' do
    let(:environment) { 'myenv' }
    it 'should return input config when config is fully-specified' do
      config = {
        'backend'     => 'default',
        'environment' => 'dev',
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }

      is_expected.to run.with_params(config, backends).and_return(config)
    end

    it "should add default 'backend' to merged config when missing" do
      input_config = {
        'environment' => 'dev',
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }
      output_config = input_config.dup
      output_config['backend'] = 'default'

      is_expected.to run.with_params(input_config, backends).
        and_return(output_config)
    end

    it "should add 'environment' to merged config when missing" do
      input_config = {
        'backend'  => 'default',
        'softfail' => true,
        'backends' => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }
      output_config = input_config.dup
      output_config['environment'] = environment

      is_expected.to run.with_params(input_config, backends).
        and_return(output_config)
    end

    it "should add 'softfail' to merged config when missing" do
      input_config = {
        'backend'  => 'default',
        'environment' => '',
        'backends' => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }
      output_config = input_config.dup
      output_config['softfail'] = false

      is_expected.to run.with_params(input_config, backends).
        and_return(output_config)
    end

    it "should add 'backends' with file backend auto-default when backends missing" do
      output_config = {
        'environment' => 'myenv',
        'softfail'    => false,
        'backend'     => 'default',
        'backends'    => {
          'default' => {
            'id'   => 'auto_default',
            'type' => 'file'
          }
        }
      }
      is_expected.to run.with_params({}, backends).
        and_return(output_config)
    end

    it 'should fail when input config is invalid' do
      options = {
        'backends' => {
          'default' => {
            'id'   => 'test',
            'type' => 'does_not_exist'
          }
        }
      }
      is_expected.to run.with_params(options, backends).
        and_raise_error(ArgumentError,
        /libkv backend plugin 'does_not_exist' not available/)
    end

  end

  context 'libkv::options specified' do
    let(:hieradata) { 'one_backend' }

    it 'should return libkv::options config when no input config is specified' do
      output_config = {
        'backend'     => 'default',
        'environment' => 'myenv',
        'softfail'    => false,
        'backends'    => {
          'default' => {
            'type'                 => 'file',
            'id'                   => 'file',
            'root_path'            => '/var/simp/libkv/file',
            'lock_timeout_seconds' => 30
          }
        }
      }

      is_expected.to run.with_params({}, backends).
        and_return(output_config)
    end

    it 'should merge input config and libkv::options but defer to input config' do
      input_config = {
        'backend'     => 'test',
        'environment' => '',
        'softfail'    => true,
        'backends'    => {
          'test' => {
            'type'      => 'file',
            'id'        => 'test',
            'root_path' => '/tmp/test',
          }
        }
      }

      output_config = {
        'backend'     => 'test',
        'environment' => '',
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'type'                 => 'file',
            'id'                   => 'file',
            'root_path'            => '/var/simp/libkv/file',
            'lock_timeout_seconds' => 30
          },
          'test' => {
            'type'      => 'file',
            'id'        => 'test',
            'root_path' => '/tmp/test',
          }
        }
      }
      is_expected.to run.with_params(input_config, backends).
        and_return(output_config)
    end


    it 'should fail when merged config is invalid' do
      input_config = { 'backend' => 'test' }

      is_expected.to run.with_params(input_config, backends).
        and_raise_error(ArgumentError,
        /No libkv backend 'test' with 'id' and 'type' attributes has been configured/)
    end
  end

  context 'backend lookup using app_id' do
    let(:hieradata) { 'multiple_backends' }

    # alias expanded version of libkv:options in multiple_backends.yaml
    let(:libkv_options) { {
      'environment' => 'myenv',
      'softfail'    => false,
      'backends'    => {
        'myapp1_special_snowflake' => {
          'type'                 => 'file',
          'id'                   => 'file',
          'root_path'            => '/var/simp/libkv/file',
          'lock_timeout_seconds' => 30
        },
        'myapp1' => {
          'type'                 => 'file',
          'id'                   => 'file',
          'root_path'            => '/var/simp/libkv/file',
          'lock_timeout_seconds' => 30
        },
        'myapp' => {
          'type'      => 'file',
          'id'        => 'alt_file',
          'root_path' => '/some/other/path'
        },
        'default' => {
          'type'                 => 'file',
          'id'                   => 'file',
          'root_path'            => '/var/simp/libkv/file',
          'lock_timeout_seconds' => 30
        }
      }
    } }

    it "should set 'backend' to match 'app_id' when exact match exists" do
      expected = libkv_options.dup
      expected['app_id'] = 'myapp1_special_snowflake'
      expected['backend'] = 'myapp1_special_snowflake'
      is_expected.to run.with_params({ 'app_id' => 'myapp1_special_snowflake' },
        backends).and_return(expected)
    end

    it "should set 'backend' to longest match of 'app_id' beginning when start with match exists" do
      expected = libkv_options.dup
      expected['app_id'] = 'myapp10'
      expected['backend'] = 'myapp1'
      is_expected.to run.with_params({ 'app_id' => 'myapp10' }, backends).
        and_return(expected)
    end

    it "should set 'backend' to default when no 'app_id' start with match is found" do
      expected = libkv_options.dup
      expected['app_id'] = 'other_myapp'
      expected['backend'] = 'default'
      is_expected.to run.with_params({ 'app_id' => 'other_myapp' }, backends).
        and_return(expected)
    end

    it "should ignore 'app_id' when 'backend' is specified" do
      expected = libkv_options.dup
      expected['app_id'] = 'myapp1'
      expected['backend'] = 'default'
      is_expected.to run.with_params({ 'app_id' => 'myapp1', 'backend' => 'default' },
        backends).and_return(expected)
    end
  end

end
