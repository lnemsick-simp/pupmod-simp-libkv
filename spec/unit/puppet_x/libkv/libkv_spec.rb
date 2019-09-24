require 'spec_helper'

require 'fileutils'
require 'tmpdir'

# mimic loading that is done in loader.rb, but be sure to load what is in
# the fixtures dir
project_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'spec', 'fixtures', 'modules', 'libkv'))
libkv_adapter_file = File.join(project_dir, 'lib', 'puppet_x', 'libkv', 'libkv.rb')
simp_libkv_adapter_class = nil
obj = Object.new
obj.instance_eval(File.read(libkv_adapter_file), libkv_adapter_file)


describe 'libkv adapter anonymous class' do

# Going to use file plugin and the test plugins in spec/support/test_plugins
# for these unit tests.

  before(:each) do
    # set up configuration for the file plugin
    @tmpdir = Dir.mktmpdir
    @root_path = File.join(@tmpdir, 'libkv', 'file')
    @options = {
      'backend'  => 'test',
      'backends' => {
        'test'  => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path
        }
      }
    }
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end


  context 'constructor' do
    it 'should load valid plugin classes' do
      expect{ simp_libkv_adapter_class.new }.to_not raise_error
      adapter = simp_libkv_adapter_class.new
      expect( adapter.plugin_classes ).to_not be_empty
      expect( adapter.plugin_classes.keys.include?('file') ).to be true
    end

    it 'should discard a plugin class with malformed Ruby' do
      allow(Puppet).to receive(:warning)
      adapter = simp_libkv_adapter_class.new
      expect(Puppet).to have_received(:warning).with(/libkv plugin from .* failed to load/)
    end
  end

  context 'helper methods' do
    before(:each) do
      @adapter = simp_libkv_adapter_class.new
    end

    context '#normalize_key' do
      let(:key) { 'my/test/key' }
      let(:normalized_key) { 'production/my/test/key' }
      it 'should add the environment in options with :add_env operation' do
        opts = {'environment' => 'production'}
        expect( @adapter.normalize_key(key, opts) ).to eq normalized_key
      end

      it 'should leave key intact when no environment specified in options with :add_env operation' do
        expect( @adapter.normalize_key(key, {}) ).to eq key
      end

      it 'should leave key intact when empty environment specified in options with :add_env operation' do
        opts = {'environment' => ''}
        expect( @adapter.normalize_key(key, opts) ).to eq key
      end

      it 'should remove the environment in options with :remove_env operation' do
        opts = {'environment' => 'production'}
        expect( @adapter.normalize_key(normalized_key, opts, :remove_env) ).to eq key
      end

      it 'should leave key intact when no environment specified in options with :remove_env operation' do
        expect( @adapter.normalize_key(normalized_key, {}, :remove_env) ).to eq normalized_key
      end

      it 'should leave key intact when empty environment specified in options with :remove_env operation' do
        opts = {'environment' => ''}
        expect( @adapter.normalize_key(normalized_key, opts, :remove_env) ).to eq normalized_key
      end

      it 'should leave key intact with any other operation' do
        opts = {'environment' => 'production'}
        expect( @adapter.normalize_key(normalized_key, opts, :oops) ).to eq normalized_key
      end
    end

    context '#plugin_instance' do
      context 'success cases' do
        it 'should create an instance when config is correct' do
          instance = @adapter.plugin_instance(@options)

          file_class_id = @adapter.plugin_classes['file'].to_s
          expect( instance.name ).to eq 'file/test'
          expect( instance.to_s ).to match file_class_id
        end

        it 'should retrieve an existing instance' do
          instance1 = @adapter.plugin_instance(@options)
          instance1_id = instance1.to_s

          instance2 = @adapter.plugin_instance(@options)
          expect(instance1_id).to eq(instance2.to_s)
        end
      end

      context 'error cases' do
        it 'should fail when options is not a Hash' do
          expect { @adapter.plugin_instance('oops') }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end

        it "should fail when options missing 'backend' key" do
          expect { @adapter.plugin_instance({}) }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end

        it "should fail when options missing 'backends' key" do
          options = {
            'backend' => 'test'
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end

        it "should fail when options 'backends' key is not a Hash" do
          options = {
            'backend'  => 'test',
            'backends' => 'oops'
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end

        it "should fail when options 'backends' does not have the specified backend" do
          options = {
            'backend'  => 'test',
            'backends' => {
              'test1' => { 'id' => 'test', 'type' => 'consul'}
            }
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end

        it "should fail when the correct 'backends' element has no 'id' key" do
          options = {
            'backend' => 'test',
            'backends' => {
              'test1' => { 'id' => 'test', 'type' => 'consul'},
              'test'  => {}
            }
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end

        it "should fail when the correct 'backends' element has no 'type' key" do
          options = {
            'backend'  => 'test',
            'backends' => {
              'test1' => { 'id' => 'test', 'type' => 'consul'},
              'test'  => { 'id' => 'test' }
            }
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end

        it "should fail when the correct 'backends' element has wrong 'type' value" do
          options = {
            'backend'  => 'test',
            'backends' => {
              'test1' => { 'id' => 'test', 'type' => 'consul'},
              'test'  => { 'id' => 'test', 'type' => 'filex' }
            }
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/libkv Internal Error: Malformed backend config/)
        end


        it 'should fail when plugin instance cannot be created' do
          options = {
            'backend'  => 'test',
            'backends' => {
              'test'  => { 'id' => 'test', 'type' => 'file' }
            }
          }

          allow(Dir).to receive(:exist?).with('/var/simp/libkv/file/test').and_return( false )
          allow(FileUtils).to receive(:mkdir_p).with('/var/simp/libkv/file/test').
            and_raise(Errno::EACCES, 'Permission denied')

          expect { @adapter.plugin_instance(options) }.
            to raise_error(/libkv Error: Unable to construct 'file\/test'/)
        end
      end
    end
  end

  context 'serialization operations' do
    before(:each) do
      @adapter = simp_libkv_adapter_class.new
    end

    let(:metadata) { {
      'foo' => 'bar',
      'baz' => 42
    } }


    data_dir = File.join(File.dirname(__FILE__), '..', '..', '..', 'support',
      'binary_data')

    binary_file1_content = IO.read(File.join(data_dir, 'test_krb5.keytab')
      ).force_encoding('ASCII-8BIT')

    binary_file2_content = IO.read(File.join(data_dir, 'random')
      ).force_encoding('ASCII-8BIT')

    testvalues = {
      'Boolean' => {
        :value            =>true,
        :serialized_value => '{"value":true,"metadata":{"foo":"bar","baz":42}}'
      },
      'valid UTF-8 String' =>  {
        :value            => 'some string',
        :serialized_value => '{"value":"some string","metadata":{"foo":"bar","baz":42}}'
      },
      'malformed UTF-8 String' => {
        :value            => binary_file1_content.dup.force_encoding('UTF-8'),
        :serialized_value =>
          '{"value":"' + Base64.strict_encode64(binary_file1_content) + '",' +
          '"encoding":"base64",' +
          '"original_encoding":"ASCII-8BIT",' +
          '"metadata":{"foo":"bar","baz":42}}',
        # only difference is encoding: deserialized value will have the
        # correct encoding of ASCII-8BIT
        :deserialized_value =>  binary_file1_content
      },
      'ASCII-8BIT String' => {
        :value            => binary_file2_content,
        :serialized_value =>
          '{"value":"' + Base64.strict_encode64(binary_file2_content) + '",' +
          '"encoding":"base64",' +
          '"original_encoding":"ASCII-8BIT",' +
          '"metadata":{"foo":"bar","baz":42}}'
      },
      'Integer' => {
        :value            => 255,
        :serialized_value =>  '{"value":255,"metadata":{"foo":"bar","baz":42}}'
      },
      'Float' => {
        :value            => 2.3849,
        :serialized_value => '{"value":2.3849,"metadata":{"foo":"bar","baz":42}}'
      },
      'Array of valid UTF-8 strings' => {
        :value            => [ 'valid UTF-8 1', 'valid UTF-8 2'],
        :serialized_value =>
          '{"value":["valid UTF-8 1","valid UTF-8 2"],' +
          '"metadata":{"foo":"bar","baz":42}}'
      },
      'Array of binary strings' => {
        :skip             => 'Not yet supported',
        :value            => [
           binary_file1_content.dup.force_encoding('UTF-8'),
           binary_file2_content
        ],
        :serialized_value => 'TBD'
      },
      'Hash with valid UTF-8 strings' => {
        :value => {
          'key1' => 'test_string',
          'key2' => 1000,
          'key3' => false,
          'key4' => { 'nestedkey1' => 'nested_test_string' }
        },
        :serialized_value =>
          '{"value":' +
          '{' +
          '"key1":"test_string",' +
          '"key2":1000,' +
          '"key3":false,' +
          '"key4":{"nestedkey1":"nested_test_string"}' +
          '},' +
          '"metadata":{"foo":"bar","baz":42}}'
      },
      'Hash with binary strings' => {
        :skip             => 'Not yet supported',
        :value => {
          'key1' => binary_file1_content.dup.force_encoding('UTF-8'),
          'key2' => 1000,
          'key3' => false,
          'key4' => { 'nestedkey1' => binary_file2_content }
        },
        :serialized_value => 'TBD'
      }
    }

    context '#serialize and #serialize_string_value' do
      testvalues.each do |summary,info|
        it "should properly serialize a #{summary}" do
          skip info[:skip] if info.has_key?(:skip)
          expect( @adapter.serialize(info[:value], metadata) ).
            to eq info[:serialized_value]
        end
      end
    end

    context '#deserialize and #deserialize_string_value' do
      testvalues.each do |summary,info|
        it "should properly deserialize a #{summary}" do
          skip info[:skip] if info.has_key?(:skip)
          expected = info.has_key?(:deserialized_value) ? info[:deserialized_value] : info[:value]
          expect( @adapter.deserialize(info[:serialized_value]) ).
            to eq({ :value => expected, :metadata => metadata })
        end
      end

      it 'should fail when input is not in JSON format' do
        expect{ @adapter.deserialize('this is not JSON')}. to raise_error(
          JSON::ParserError)
      end

      it "should fail when input does not have 'value' key" do
        expect{ @adapter.deserialize('{"Value":255}')}. to raise_error(
          RuntimeError, /Failed to deserialize: 'value' missing/)
      end

      it "should fail when input has unsupported 'encoding' key" do
        serialized_value = '{"value":"some value","encoding":"oops",' +
          '"original_encoding":"ASCII-8BIT"}'
        expect{ @adapter.deserialize(serialized_value)}. to raise_error(
          RuntimeError, /Failed to deserialize: Unsupported encoding/)
      end
    end

    context '#serialize and #deserialize' do
    end
  end

  context 'public API' do
    before(:each) do
      @adapter = simp_libkv_adapter_class.new

      # create our own file plugin instance so we can manipulate key/store
      # independent of the libkv adapter
      @plugin = @adapter.plugin_classes['file'].new('other', @options)
    end

    context '#backends' do
      it 'should list available backend plugins' do
        # currently only 1 plugins
        expect( @adapter.backends ).to eq([ 'file' ])
      end
    end

    context '#delete' do
    end

  end

=begin
    context 'error cases' do
      it 'should fail when options is not a Hash' do
        expect { simp_libkv_adapter_class.new('file/test', 'oops') }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end

      it "should fail when options missing 'backend' key" do
        expect { simp_libkv_adapter_class.new('file/test', {} ) }.
          to raise_error(/libkv plugin file\/test misconfigured: {}/)
      end

      it "should fail when options missing 'backends' key" do
        options = {
          'backend' => 'test'
        }
        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured: {.*backend.*}/)
      end

      it "should fail when options 'backends' key is not a Hash" do
        options = {
          'backend'  => 'test',
          'backends' => 'oops'
        }
        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end

      it "should fail when options 'backends' does not have the specified backend" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'}
          }
        }
        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end

      it "should fail when the correct 'backends' element has no 'id' key" do
        options = {
          'backend' => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'},
            'test'  => {}
          }
        }
        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end

      it "should fail when the correct 'backends' element has no 'type' key" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'},
            'test'  => { 'id' => 'test' }
          }
        }
        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end

      it "should fail when the correct 'backends' element has wrong 'type' value" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'},
            'test'  => { 'id' => 'test', 'type' => 'filex' }
          }
        }
        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end


      it "should fail when root path cannot be created" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test'  => { 'id' => 'test', 'type' => 'file' }
          }
        }

        allow(Dir).to receive(:exist?).with('/var/simp/libkv/file/test').and_return( false )
        allow(FileUtils).to receive(:mkdir_p).with('/var/simp/libkv/file/test').
          and_raise(Errno::EACCES, 'Permission denied')

        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test Error: Unable to create .* Permission denied/)
      end

      it "should fail when root path permissions cannot be set" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test'  => { 'id' => 'test', 'type' => 'file' }
          }
        }

        allow(Dir).to receive(:exist?).with('/var/simp/libkv/file/test').and_return( false )
        allow(FileUtils).to receive(:mkdir_p).with('/var/simp/libkv/file/test').
          and_return(true)
        allow(FileUtils).to receive(:chmod).with(0750, '/var/simp/libkv/file/test').
          and_raise(Errno::EACCES, 'Permission denied')

        expect { simp_libkv_adapter_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test Error: Unable to set permissions .* Permission denied/)
      end

    end
  end

  context 'public API' do
    before(:each) do
      @tmpdir = Dir.mktmpdir
      @root_path = File.join(@tmpdir, 'libkv', 'file')
      @options = {
        'backend'  => 'test',
        'backends' => {
          'test'  => {
            'id'                   => 'test',
            'type'                 => 'file',
            'root_path'            => @root_path,
            'lock_timeout_seconds' => 1
          }
        }
      }
      @plugin = simp_libkv_adapter_class.new('file/test', @options)
    end

    after(:each) do
      # in case one of the tests that removes directory ready permissions fails...
      FileUtils.chmod_R('u=rwx', @tmpdir)

      FileUtils.remove_entry_secure(@tmpdir)
    end

    describe 'delete' do
      it 'should return :result=true when the key file does not exist' do
        expect( @plugin.delete('does/not/exist/key')[:result] ).to be true
        expect( @plugin.delete('does/not/exist/key')[:err_msg] ).to be_nil
      end

      it 'should return :result=true when the key file can be deleted' do
        key_file = File.join(@root_path, 'key1')
        FileUtils.touch(key_file)
        expect( @plugin.delete('key1')[:result] ).to be true
        expect( @plugin.delete('key1')[:err_msg] ).to be_nil
        expect( File.exist?(key_file) ).to be false
      end

      it 'should return :result=false and an :err_msg when the key file delete fails' do
        # make a key file that is inaccessible
        key_file = File.join(@root_path, 'production/key1')
        FileUtils.mkdir_p(File.dirname(key_file))
        FileUtils.touch(key_file)
        FileUtils.chmod(0400, File.dirname(key_file))
        result = @plugin.delete('production/key1')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Delete failed:/)
        FileUtils.chmod(0770, File.dirname(key_file))
        expect( File.exist?(key_file) ).to be true
      end
    end

    describe 'deletetree' do
      it 'should return :result=true when the key folder does not exist' do
        expect( @plugin.deletetree('does/not/exist/folder')[:result] ).to be true
        expect( @plugin.deletetree('does/not/exist/folder')[:err_msg] ).to be_nil
      end

      it 'should return :result=true when the key folder can be deleted' do
        key_dir = File.join(@root_path, 'production')
        FileUtils.mkdir_p(key_dir)
        FileUtils.touch(File.join(key_dir, 'key1'))
        FileUtils.touch(File.join(key_dir, 'key2'))
        expect( @plugin.deletetree('production')[:result] ).to be true
        expect( @plugin.deletetree('production')[:err_msg] ).to be_nil
        expect( Dir.exist?(key_dir) ).to be false
      end

      it 'should return :result=false and an :err_msg when the key folder delete fails' do
        # make a key file that is inaccessible so that recursive delete fails
        key_dir = File.join(@root_path, 'production/gen_passwd')
        FileUtils.mkdir_p(key_dir)
        key_file = File.join(key_dir, 'key1')
        FileUtils.touch(key_file)
        FileUtils.chmod(0400, File.dirname(key_file))
        result = @plugin.deletetree('production/gen_passwd')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Folder delete failed:/)
        FileUtils.chmod(0770, File.dirname(key_file))
        expect( Dir.exist?(key_dir) ).to be true
      end
    end

    describe 'exists' do
      it 'should return :result=false when the key file does not exist' do
        result = @plugin.exists('does/not/exist/key')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return :result=true when the key file exists and is accessible' do
        key_file = File.join(@root_path, 'key1')
        FileUtils.touch(key_file)
        result = @plugin.exists('key1')
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return :result=false when the key file exists but is not accessible' do
        # make a key file that is inaccessible
        key_file = File.join(@root_path, 'production/key1')
        FileUtils.mkdir_p(File.dirname(key_file))
        FileUtils.touch(key_file)
        FileUtils.chmod(0400, File.dirname(key_file))
        result = @plugin.exists('production/key1')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to be_nil
        FileUtils.chmod(0770, File.dirname(key_file))
      end
    end

    describe 'get' do
      it 'should return set :result when the key file exists and is accessible' do
        key_file = File.join(@root_path, 'key1')
        value = 'value for key1'
        File.open(key_file, 'w') { |file| file.write(value) }
        result = @plugin.get('key1')
        expect( result[:result] ).to eq value
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return an unset :result and an :err_msg when the key file does not exist' do
        result = @plugin.get('does/not/exist/key')
        expect( result[:result] ).to be_nil
        expect( result[:err_msg] ).to match(/Key not found/)
      end

      it 'should return an unset :result and an :err_msg when times out waiting for key lock' do
        key = 'key1'
        value = 'value for key1'
        locked_key_file_operation(@root_path, key, value) do
          puts "     >> Executing plugin get() for '#{key}'"
          result = @plugin.get(key)
          expect( result[:result] ).to be_nil
          expect( result[:err_msg] ).to match /Timed out waiting for key file lock/
        end

        # just to be sure lock is appropriately cleared...
        result = @plugin.get(key)
        expect( result[:result] ).to_not be_nil
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return an unset :result and an :err_msg when the key file exists but is not accessible' do
        # make a key file that is inaccessible
        key_file = File.join(@root_path, 'production/key1')
        FileUtils.mkdir_p(File.dirname(key_file))
        File.open(key_file, 'w') { |file| file.write('value for key1') }
        FileUtils.chmod(0400, File.dirname(key_file))
        result = @plugin.get('production/key1')
        expect( result[:result] ).to be_nil
        expect( result[:err_msg] ).to match(/Key retrieval failed/)
        FileUtils.chmod(0770, File.dirname(key_file))
      end
    end

    # using plugin's put() in this test, because it is fully tested below
    describe 'list' do

      it 'should return an empty :result when key folder is empty' do
        key_dir = File.join(@root_path, 'production')
        FileUtils.mkdir_p(key_dir)
        result = @plugin.list('production')
        expect( result[:result] ).to eq({})
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return full list of key/value pairs in :result when key folder content is accessible' do
        expected = {
          'production/key1' => 'value for key1',
          'production/key2' => 'value for key2',
          'production/key3' => 'value for key3'
        }
        expected.each { |key,value| @plugin.put(key, value) }
        result = @plugin.list('production')
        expect( result[:result] ).to eq(expected)
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return partial list of key/value pairs in :result when some key folder content is not accessible' do
        expected = {
          'production/key1' => 'value for key1',
          'production/key3' => 'value for key3'
        }
        expected.each { |key,value| @plugin.put(key, value) }

        # create a file for 'production/key2', but make it inaccessible via a lock
        locked_key_file_operation(@root_path, 'production/key2', 'value for key2') do
          puts "     >> Executing plugin list() for 'production'"
          result = @plugin.list('production')
          expect( result[:result] ).to eq(expected)
          expect( result[:err_msg] ).to be_nil
        end

      end

      it 'should return an unset :result and an :err_msg when key folder exists but is not accessible' do
        # create inaccessible key folder that has content
        @plugin.put('production/gen_passwd/key1', 'value for key1')
        FileUtils.chmod(0400, File.join(@root_path, 'production'))
        result = @plugin.list('production/gen_passwd')
        FileUtils.chmod(0770, File.join(@root_path, 'production'))
        expect( result[:result] ).to be_nil
        expect( result[:err_msg] ).to match(/Key folder not found/)
      end

      it 'should return an unset :result  and an :err_msg when key folder does not exist' do
        result = @plugin.list('production')
        expect( result[:result] ).to be_nil
        expect( result[:err_msg] ).to match(/Key folder not found/)
      end
    end

    describe 'name' do
      it 'should return configured name' do
        expect( @plugin.name ).to eq 'file/test'
      end
    end

    # using plugin's get() in this test, because it has already been
    # fully tested
    describe 'put' do
      it 'should return :result=true when the key file does not exist for a simple key' do
        key = 'key1'
        value = 'value for key1'
        result = @plugin.put(key, value)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
        expect( @plugin.get(key)[:result] ).to eq value
      end

      it 'should return :result=true when the key file does not exist for a complex key' do
        key = 'production/gen_passwd/key1'
        value = 'value for key1'
        result = @plugin.put(key, value)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
        expect( @plugin.get(key)[:result] ).to eq value
      end

      it 'should return :result=true when the key file exists and is accessible' do
        key = 'key1'
        value1 = 'value for key1 which is longer than second value'
        value2 = 'second value for key1'
        value3 = 'third value for key1 which is longer than second value'
        @plugin.put(key, value1)

        result = @plugin.put(key, value2)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
        expect( @plugin.get(key)[:result] ).to eq value2

        result = @plugin.put(key, value3)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
        expect( @plugin.get(key)[:result] ).to eq value3
      end

      it 'should return :result=false and an :err_msg when times out waiting for key lock' do
        key = 'key1'
        value1 = 'first value for key1'
        value2 = 'second value for key1'

        locked_key_file_operation(@root_path, key, value1) do
          puts "     >> Executing plugin.put() for '#{key}'"
          result = @plugin.put(key, value2)
          expect( result[:result] ).to be false
          expect( result[:err_msg] ).to match /Timed out waiting for key file lock/
        end

        # just to be sure lock is appropriately cleared...
        result = @plugin.put(key, value2)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return :result=false an an :err_msg when the key file exists but is not accessible' do
        # make a key file that is inaccessible
        key = 'production/gen_passwd/key1'
        value1 = 'first value for key1'
        value2 = 'second value for key1'
        @plugin.put(key, value1)
        key_parent_dir = File.join(@root_path, 'production', 'gen_passwd')
        FileUtils.chmod(0400, key_parent_dir)

        result = @plugin.put(key, value2)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Key write failed/)
        FileUtils.chmod(0770, key_parent_dir)
        expect( @plugin.get(key)[:result] ).to eq value1
      end
    end
  end
=end

end
