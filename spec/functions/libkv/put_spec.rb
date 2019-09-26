require 'spec_helper'

describe 'libkv::put' do

# Going to use file plugin and the test plugins in spec/support/test_plugins
# for these unit tests.
  before(:each) do
    # set up configuration for the file plugin
    @tmpdir = Dir.mktmpdir
    @root_path_test_file = File.join(@tmpdir, 'libkv', 'test_file')
    @root_path_default   = File.join(@tmpdir, 'libkv', 'default')
    options_base = {
      'environment' => 'production',
      'backends'    => {
        # will use failer plugin for catastrophic error cases, because
        # it is badly behaved and raises exceptions on all operations
       'test_failer'  => {
          'id'               => 'test',
          'type'             => 'failer',
          'fail_constructor' => false  # true = raise in constructor
        },
        # will use file plugin for non-catastrophic test cases
        'test_file'  => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path_test_file
        },
        'default'  => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path_default
        }
      }
    }
    @options_failer     = options_base.merge ({ 'backend' => 'test_failer' } )
    @options_test_file  = options_base.merge ({ 'backend' => 'test_file' } )
    @options_default    = options_base
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  context 'without libkv::options' do
    it 'should store key,value pair to a specific backend in options' do
    end

    it 'should store key,value pair to the default backend in options' do
    end

    it 'should store key,value,metadata tuple to the specified backend' do
    end

    it 'should use environment-less key when environment is empty' do
    end

    it 'should fail when backend put fails and `softfail` is false' do
    end

    it 'should return false when backend put fails and `softfail` is true' do
    end
  end

  context 'with libkv::options' do
  end

  context 'other error cases' do
    it 'should fail when key fails validation' do
      params = [ '$this is an invalid key!', 'value', {}, @options_test_file ]
      is_expected.to run.with_params(*params).
        and_raise_error(ArgumentError, /contains disallowed whitespace/)
    end

    it 'should fail when libkv cannot be added to the catalog instance' do
      allow(File).to receive(:exists?).and_return(false)
      is_expected.to run.with_params('mykey', 'myvalue' , {}, @options_test_file).
        and_raise_error(LoadError, /libkv Internal Error: unable to load/)
    end

    it 'should fail when merged libkv options is invalid' do
      bad_options  = @options_default.merge ({ 'backend' => 'oops_backend' } )
      is_expected.to run.with_params('mykey', 'myvalue' , {}, bad_options).
        and_raise_error(ArgumentError,
        /libkv Configuration Error for libkv::put with key='mykey'/)
    end
  end

end
