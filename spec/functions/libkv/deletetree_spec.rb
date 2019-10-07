require 'spec_helper'

describe 'libkv::deletetree' do

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

  let(:keydir) { 'app1' }

  # The tests will verify most of the function behavior without libkv::options
  # specified and then verify options merging when libkv::options is specified.

  context 'without libkv::options' do
    let(:test_file_env_root_dir) { File.join(@root_path_test_file, 'production') }
    let(:default_app_id_env_root_dir) { File.join(@root_path_default_app_id, 'production') }
    let(:default_env_root_dir) { File.join(@root_path_default, 'production') }

    it 'should delete an existing, non-empty key folder in a specific backend in options' do
      actual_keydir = File.join(test_file_env_root_dir, keydir)
      FileUtils.mkdir_p(actual_keydir)
      key_file = File.join(actual_keydir, 'key')
      FileUtils.touch(key_file)

      is_expected.to run.with_params(keydir, @options_test_file).and_return(true)
      expect( Dir.exist?(actual_keydir) ).to be false
    end

    it 'should delete an existing key folder in the default backend in options when app_id unspecified' do
      actual_keydir = File.join(default_env_root_dir, keydir)
      FileUtils.mkdir_p(actual_keydir)
      key_file = File.join(actual_keydir, 'key')
      FileUtils.touch(key_file)

      is_expected.to run.with_params(keydir, @options_default).and_return(true)
      expect( Dir.exist?(actual_keydir) ).to be false
    end

    it 'should delete an existing key folder in the default backend for app_id' do
      actual_keydir = File.join(default_app_id_env_root_dir, keydir)
      FileUtils.mkdir_p(actual_keydir)
      key_file = File.join(actual_keydir, 'key')
      FileUtils.touch(key_file)

      is_expected.to run.with_params(keydir, @options_default_app_id).and_return(true)
      expect( Dir.exist?(actual_keydir) ).to be false
    end

    it 'should delete an existing key folder in the auto-default backend when backend config missing' do
      # mocking is REQUIRED for GitLab
      allow(Dir).to receive(:exist?).with(any_args).and_call_original
      allow(Dir).to receive(:exist?).with('/var/simp/libkv/file/auto_default').and_return( false )
      allow(FileUtils).to receive(:mkdir_p).with(any_args).and_call_original
      allow(FileUtils).to receive(:mkdir_p).with('/var/simp/libkv/file/auto_default').
        and_raise(Errno::EACCES, 'Permission denied')

      # The test's Puppet.settings[:vardir] gets created when the subject (function object)
      # is constructed
      subject()
      actual_keydir = File.join(Puppet.settings[:vardir], 'simp', 'libkv', 'file',
        'auto_default', environment, keydir)
      FileUtils.mkdir_p(File.dirname(actual_keydir))

      is_expected.to run.with_params(keydir, @options_default_app_id).and_return(true)
      expect( Dir.exist?(actual_keydir) ).to be false
    end

    it 'should delete an existing empty key folder in a specific backend in options' do
      actual_keydir = File.join(test_file_env_root_dir, keydir)
      FileUtils.mkdir_p(actual_keydir)

      is_expected.to run.with_params(keydir, @options_test_file).and_return(true)
      expect( Dir.exist?(actual_keydir) ).to be false
    end

    it 'should succeed even when the key folder does not exist in a specific backend in options' do
      is_expected.to run.with_params(keydir, @options_test_file).and_return(true)
    end

    it 'should use environment-less key folder when environment is empty' do
      options = @options_default.dup
      options['environment'] = ''
      actual_keydir = File.join(@root_path_default, keydir)
      FileUtils.mkdir_p(actual_keydir)

      is_expected.to run.with_params(keydir, options).and_return(true)
      expect( File.exist?(actual_keydir) ).to be false
    end

    it 'should fail when backend deletetree fails and `softfail` is false' do
      is_expected.to run.with_params(keydir, @options_failer).
        and_raise_error(RuntimeError, /libkv Error for libkv::deletetree with keydir='#{keydir}'/)
    end

    it 'should log warning and return false when backend deletetree fails and `softfail` is true' do
      options = @options_failer.dup
      options['softfail'] = true

      is_expected.to run.with_params(keydir, options).and_return(false)

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
      actual_keydir = File.join(@root_path_default, 'myenv', keydir)
      FileUtils.mkdir_p(actual_keydir)
      is_expected.to run.with_params(keydir, options).and_return(true)
      expect( File.exist?(actual_keydir) ).to be false
    end
  end

  context 'other error cases' do
    it 'should fail when key folder fails validation' do
      params = [ '$this is an invalid key folder!', @options_test_file ]
      is_expected.to run.with_params(*params).
        and_raise_error(ArgumentError, /contains disallowed whitespace/)
    end

    it 'should fail when libkv cannot be added to the catalog instance' do
      allow(File).to receive(:exists?).and_return(false)
      is_expected.to run.with_params(keydir, @options_test_file).
        and_raise_error(LoadError, /libkv Internal Error: unable to load/)
    end

    it 'should fail when merged libkv options is invalid' do
      bad_options  = @options_default.merge ({ 'backend' => 'oops_backend' } )
      is_expected.to run.with_params(keydir, bad_options).
        and_raise_error(ArgumentError,
        /libkv Configuration Error for libkv::deletetree with keydir='#{keydir}'/)
    end
  end

end
