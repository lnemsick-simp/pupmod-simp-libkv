require 'spec_helper'

describe 'libkv::get_backend_config' do

  let(:backends) { [ 'file' ] }
  let(:class_resource)           { 'Class[Mymodule::Myclass]' }

  context 'libkv::options not specified' do
    let(:environment) { 'myenv' }
    it 'should return input config when config is fully-specified' do
      config = {
        'backend'     => 'file',
        'environment' => 'dev',
        'softfail'    => true,
        'backends'    => {
          'file' => {
            'id'   => 'test',
            'type' => 'file'
          },
        }
      }

      is_expected.to run.with_params(config, backends, class_resource).
        and_return(config)
    end

    it "should add default 'backend' to merged config when missing" do
      input_config = {
        'environment' => 'dev',
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          },
        }
      }
      output_config = input_config.dup
      output_config['backend'] = 'default'

      is_expected.to run.with_params(input_config, backends, class_resource).
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
          },
        }
      }
      output_config = input_config.dup
      output_config['environment'] = environment

      is_expected.to run.with_params(input_config, backends, class_resource).
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
          },
        }
      }
      output_config = input_config.dup
      output_config['softfail'] = false

      is_expected.to run.with_params(input_config, backends, class_resource).
        and_return(output_config)
    end

    it 'should fail when input config is invalid' do
      options = {}
      is_expected.to run.with_params(options, backends, class_resource).
        and_raise_error(ArgumentError,
        /'backends' not specified in libkv configuration/)
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

      is_expected.to run.with_params({}, backends, class_resource).
        and_return(output_config)
    end

    it 'should merge input config and libkv::options but defer to input config' do
      input_config = {
        'backend'     => 'test',
        'environment' => '',
        'softfail'    => true,
        'backends'    => {
          'test' => {
            'type'                 => 'file',
            'id'                   => 'test',
            'root_path'            => '/tmp/test',
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
            'type'                 => 'file',
            'id'                   => 'test',
            'root_path'            => '/tmp/test',
          }
        }
      }
      is_expected.to run.with_params(input_config, backends, class_resource).
        and_return(output_config)
    end


    it 'should fail when merged config is invalid' do
      input_config = { 'backend' => 'test' }

      is_expected.to run.with_params(input_config, backends, class_resource).
        and_raise_error(ArgumentError,
        /No libkv backend 'test' with 'id' and 'type' attributes has been configured/)
    end
  end

  context 'backend lookup using default hierarchy' do
    context 'complete hierarchy specified' do
      let(:hieradata) { 'multiple_backends' }

      # alias expanded version of libkv:options in multiple_backends.yaml
      let(:libkv_options) { {
        'environment' => 'myenv',
        'softfail'    => false,
        'backends'    => {
          'default.Class[Mymodule::Myclass]' => {
            'type'                 => 'file',
            'id'                   => 'file',
            'root_path'            => '/var/simp/libkv/file',
            'lock_timeout_seconds' => 30
          },
          'default.Mymodule::Mydefine[myinstance]' => {
            'type'       => 'file',
            'id'        => 'alt_file',
            'root_path' => '/some/other/path'
          },
          'default.Mymodule::Mydefine' => {
            'type'                 => 'file',
            'id'                   => 'file',
            'root_path'            => '/var/simp/libkv/file',
            'lock_timeout_seconds' => 30
          },
          'default' => {
            'type'                 => 'file',
            'id'                   => 'file',
            'root_path'            => '/var/simp/libkv/file',
            'lock_timeout_seconds' => 30
          }
        }
      } }

      it "should set 'backend' to matching Class default" do
        expected = libkv_options.dup
        expected['backend'] = "default.#{class_resource}"
        is_expected.to run.with_params({}, backends, class_resource).
          and_return(expected)
      end

      it "should set 'backend' to matching Define-instance default" do
        expected = libkv_options.dup
        matching_instance =  'Mymodule::Mydefine[myinstance]'
        expected['backend'] = 'default.Mymodule::Mydefine[myinstance]'
        is_expected.to run.with_params({}, backends, matching_instance).
          and_return(expected)
      end

      it "should set 'backend' to matching Define default" do
        expected = libkv_options.dup
        other_instance =  'Mymodule::Mydefine[yourinstance]'
        expected['backend'] = 'default.Mymodule::Mydefine'
        is_expected.to run.with_params({}, backends, other_instance).
          and_return(expected)
      end

      it "should set 'backend' to default when no match is found" do
        expected = libkv_options.dup
        expected['backend'] = 'default'
        is_expected.to run.with_params({}, backends, 'Class[Bob]').
          and_return(expected)
      end
    end

    context "hierarchy missing 'default'" do
      let(:hieradata) { 'multiple_backends_missing_default' }

      it "should fail when no match is found and 'default' backend not specified" do
        is_expected.to run.with_params({}, backends, 'Class[Bob]').
        and_raise_error(ArgumentError,
        /No libkv backend 'default' with 'id' and 'type' attributes has been configured/)
      end
    end
  end

end
