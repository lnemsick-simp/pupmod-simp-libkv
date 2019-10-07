require 'spec_helper'

describe 'libkv::put' do

# Going to use file plugin and the test plugins in spec/support/test_plugins
# for these unit tests.
  before(:each) do
    # set up configuration for the file plugin
    @tmpdir = Dir.mktmpdir
    @root_path_test_file      = File.join(@tmpdir, 'libkv', 'test_file')
    @root_path_default_app_id = File.join(@tmpdir, 'libkv', 'default_app_id')
    @root_path_default        = File.join(@tmpdir, 'libkv', 'default')
    options_base = {
      'environment' => 'production',
      'backends'    => {
        # will use failer plugin for catastrophic error cases, because
        # it is badly behaved and raises exceptions on all operations
       'test_failer' => {
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
        'myapp'      => {
          'id'        => 'default_app_id',
          'type'      => 'file',
          'root_path' => @root_path_default_app_id
        },
        'default'    => {
          'id'        => 'default',
          'type'      => 'file',
          'root_path' => @root_path_default
        }
      }
    }
    @options_failer         = options_base.merge ({ 'backend' => 'test_failer' } )
    @options_test_file      = options_base.merge ({ 'backend' => 'test_file' } )
    @options_default_app_id = options_base.merge ({ 'app_id'  => 'myapp10' } )
    @options_default        = options_base
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  # The tests will verify most of the function behavior without libkv::options
  # specified and then verify options merging when libkv::options is specified.

  context 'without libkv::options' do
    let(:key) { 'mykey' }
    let(:value) { 'myvalue' }
    let(:metadata) { { 'foo' => 'bar', 'baz' => 42 } }

    data_info.each do |summary,info|
      it "should store key with #{summary} value + metadata to a specific backend in options" do
        skip info[:skip] if info.has_key?(:skip)

        params = [ key, info[:value] , info[:metadata], @options_test_file ]
        is_expected.to run.with_params(*params).and_return(true)

        key_file = File.join(@root_path_test_file, 'production', key)
        expect( File.exist?(key_file) ).to be true
        expect( File.read(key_file) ).to eq(info[:serialized_value])
      end
    end

    it 'should store key,value,metadata tuple to the default backend in options when app_id unspecified' do
      is_expected.to run.with_params(key, value , metadata, @options_default).
        and_return(true)

      key_file = File.join(@root_path_default, 'production', key)
      expect( File.exist?(key_file) ).to be true
    end

    it 'should store key,value,metadata tuple to the auto-default backend when backend config missing'  do
      # mocking is REQUIRED for GitLab
      allow(Dir).to receive(:exist?).with('/var/simp/libkv/file/auto_default').and_return( false )
      allow(FileUtils).to receive(:mkdir_p).with(any_args).and_call_original
      allow(FileUtils).to receive(:mkdir_p).with('/var/simp/libkv/file/auto_default').
        and_raise(Errno::EACCES, 'Permission denied')

      is_expected.to run.with_params(key, value, metadata).and_return(true)

      key_file = File.join(Puppet.settings[:vardir], 'simp', 'libkv', 'file',
        'auto_default', environment, key)
      expect( File.exist?(key_file) ).to be true
    end

    it 'should store key,value,metadata tuple to the default backend for app_id' do
      is_expected.to run.with_params(key, value , metadata, @options_default_app_id).
        and_return(true)

      key_file = File.join(@root_path_default_app_id, 'production', key)
      expect( File.exist?(key_file) ).to be true
    end

    it 'should use environment-less key when environment is empty' do
      options = @options_default.dup
      options['environment'] = ''
      is_expected.to run.with_params(key, value , metadata, options).
        and_return(true)

      env_key_file = File.join(@root_path_default, 'production', key)
      expect( File.exist?(env_key_file) ).to be false

      key_file = File.join(@root_path_default, key)
      expect( File.exist?(key_file) ).to be true
    end

    it 'should fail when backend put fails and `softfail` is false' do
      is_expected.to run.with_params(key, value , metadata, @options_failer).
        and_raise_error(RuntimeError, /libkv Error for libkv::put with key='#{key}'/)
    end

    it 'should log warning and return false when backend put fails and `softfail` is true' do
      options = @options_failer.dup
      options['softfail'] = true

      is_expected.to run.with_params(key, value , metadata, options).
        and_return(false)

      #FIXME check warning log
    end
  end

  context 'with libkv::options' do
    let(:hieradata) { 'multiple_backends_missing_default' }

    it 'should merge libkv::options' do
      # @options_default will add the missing default backend config and
      # override the environment setting.  To spot check options merge (which
      # is fully tested elsewhere), remove the environment setting and verify
      # we use the default config from the local options Hash and the
      # environment from libkv::options
      options = @options_default.dup
      options.delete('environment')
      is_expected.to run.with_params('key', 'value', {}, options).
        and_return(true)

      key_file = File.join(@root_path_default, 'myenv', 'key')
      expect( File.exist?(key_file) ).to be true
    end
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
