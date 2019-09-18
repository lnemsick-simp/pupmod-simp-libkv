require 'spec_helper'

require 'fileutils'
require 'tmpdir'

# mimic loading that is done in libkv.rb
project_dir = File.join(File.dirname(__FILE__), '..', '..', '..', '..')
plugin_file = File.join(project_dir, 'lib', 'puppet_x', 'libkv', 'file_plugin.rb')
plugin_class = nil
obj = Object.new
obj.instance_eval(File.read(plugin_file), plugin_file)

describe 'libkv file plugin anonymous class' do
  context 'type' do
    it "class.type should return 'file'" do
      expect(plugin_class.type).to eq 'file'
    end
  end

  context 'constructor' do
    context 'success cases' do
      before(:each) do
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

      it 'should create the root_path tree when none exists' do
        expect{ plugin_class.new('file/test', @options) }.to_not raise_error
        expect( File.exist?(@root_path) ).to be true
      end

      it 'should not fail if the root_path tree exists' do
        FileUtils.mkdir_p(@root_path)
        expect { plugin_class.new('file/test', @options) }.to_not raise_error
      end

      it 'should fix the permissions of root_path' do
        FileUtils.mkdir_p(@root_path, :mode => 0755)
        expect{ plugin_class.new('file/test', @options) }.to_not raise_error
        expect( File.stat(@root_path).mode & 0777 ).to eq 0750
      end
    end

    context 'error cases' do
      it 'should fail when options is not a Hash' do
        expect { plugin_class.new('file/test', 'oops') }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end

      it "should fail when options missing 'backend' key" do
        expect { plugin_class.new('file/test', {} ) }.
          to raise_error(/libkv plugin file\/test misconfigured: {}/)
      end

      it "should fail when options missing 'backends' key" do
        options = {
          'backend' => 'test'
        }
        expect { plugin_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured: {.*backend.*}/)
      end

      it "should fail when options 'backends' key is not a Hash" do
        options = {
          'backend'  => 'test',
          'backends' => 'oops'
        }
        expect { plugin_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test misconfigured/)
      end

      it "should fail when options 'backends' does not have the specified backend" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'}
          }
        }
        expect { plugin_class.new('file/test', options) }.
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
        expect { plugin_class.new('file/test', options) }.
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
        expect { plugin_class.new('file/test', options) }.
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
        expect { plugin_class.new('file/test', options) }.
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

        expect { plugin_class.new('file/test', options) }.
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

        expect { plugin_class.new('file/test', options) }.
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
      @plugin = plugin_class.new('file/test', @options)
    end

    after(:each) do
      # in case one of the tests that removes directory ready permissions fails...
      FileUtils.chmod_R('u=rwx', @tmpdir)

      FileUtils.remove_entry_secure(@tmpdir)
    end

    describe 'delete' do
      it 'should return empty Hash (success) when the key file does not exist' do
        expect( @plugin.delete('does/not/exist/key') ).to eq({})
      end

      it 'should return empty Hash (success) when the key file can be deleted' do
        key_file = File.join(@root_path, 'key1')
        FileUtils.touch(key_file)
        expect( @plugin.delete('key1') ).to eq({})
        expect( File.exist?(key_file) ).to be false
      end

      it 'should return Hash with :err_msg (failure) when the key file delete fails' do
        # make a key file that is inaccessible
        key_file = File.join(@root_path, 'production/key1')
        FileUtils.mkdir_p(File.dirname(key_file))
        FileUtils.touch(key_file)
        FileUtils.chmod(0400, File.dirname(key_file))
        result = @plugin.delete('production/key1')
        expect( result[:err_msg] ).to match(/Delete failed:/)
        FileUtils.chmod(0770, File.dirname(key_file))
        expect( File.exist?(key_file) ).to be true
      end
    end

    describe 'deletetree' do
      it 'should return empty Hash (success) when the key folder does not exist' do
        expect( @plugin.delete('does/not/exist/folder') ).to eq({})
      end

      it 'should return empty Hash (success) when the key folder can be deleted' do
        key_dir = File.join(@root_path, 'production')
        FileUtils.mkdir_p(key_dir)
        FileUtils.touch(File.join(key_dir, 'key1'))
        FileUtils.touch(File.join(key_dir, 'key2'))
        expect( @plugin.deletetree('production') ).to eq({})
        expect( Dir.exist?(key_dir) ).to be false
      end

      it 'should return Hash with :err_msg (failure) when the key folder delete fails' do
        # make a key file that is inaccessible so that recursive delete fails
        key_dir = File.join(@root_path, 'production/gen_passwd')
        FileUtils.mkdir_p(key_dir)
        key_file = File.join(key_dir, 'key1')
        FileUtils.touch(key_file)
        FileUtils.chmod(0400, File.dirname(key_file))
        result = @plugin.deletetree('production/gen_passwd')
        expect( result[:err_msg] ).to match(/Folder delete failed:/)
        FileUtils.chmod(0770, File.dirname(key_file))
        expect( Dir.exist?(key_dir) ).to be true
      end
    end

    describe 'exists' do
      it 'should return Hash with :present = false when the key file does not exist' do
        expect( @plugin.exists('does/not/exist/key') ).to eq({ :present => false })
      end

      it 'should return Hash with :present = true when the key file exists and is accessible' do
        key_file = File.join(@root_path, 'key1')
        FileUtils.touch(key_file)
        expect( @plugin.exists('key1') ).to eq({ :present => true })
      end

      it 'should return Hash with :present = false when the key file exists but is not accessible' do
        # make a key file that is inaccessible
        key_file = File.join(@root_path, 'production/key1')
        FileUtils.mkdir_p(File.dirname(key_file))
        FileUtils.touch(key_file)
        FileUtils.chmod(0400, File.dirname(key_file))
        expect( @plugin.exists('production/key1') ).to eq({ :present => false })
        FileUtils.chmod(0770, File.dirname(key_file))
      end
    end

    describe 'get' do
      it 'should return Hash with :value when the key file exists and is accessible' do
        key_file = File.join(@root_path, 'key1')
        value = 'value for key1'
        File.open(key_file, 'w') { |file| file.write(value) }
        result = @plugin.get('key1')
        expect( result[:value] ).to eq value
        expect( result.has_key?(:err_msg) ).to be false
      end

      it 'should return Hash with :err_msg when the key file does not exist' do
        result = @plugin.get('does/not/exist/key')
        expect( result[:err_msg] ).to match(/Key not found/)
      end

      it 'should return Hash with :err_msg when times out waiting for key lock' do
        key_file = File.join(@root_path, 'key1')
        value = 'value for key1'
        File.open(key_file, 'w') { |file| file.write(value) }

        locker_thread = nil
        get_thread = nil
        locked = false
        begin
          locker_thread = Thread.new do
             puts "     >> Locking key file #{key_file}"
             file = File.open(key_file, 'r')
             file.flock(File::LOCK_EX)
             locked = true
             # pause the thread
             Thread.stop
             file.flock(File::LOCK_UN)
             puts '     >> Lock released'
          end

          sleep 0.5 while !locked
          puts "     >> Executing get for key file #{key_file}"
          result = @plugin.get('key1')
          expect( result.has_key?(:value) ).to be false
          expect( result[:err_msg] ).to match /Timed out waiting for key file lock/
        ensure
          if locker_thread
            # wait until thread paused
            sleep 0.5 while locker_thread.status != 'sleep'

            # resume and then wait until thread completed
            locker_thread.run
            locker_thread.join
          end
        end
      end

      it 'should return Hash with :err_msg when the key file exists but is not accessible' do
        # make a key file that is inaccessible
        key_file = File.join(@root_path, 'production/key1')
        FileUtils.mkdir_p(File.dirname(key_file))
        File.open(key_file, 'w') { |file| file.write('value for key1') }
        FileUtils.chmod(0400, File.dirname(key_file))
        result = @plugin.get('production/key1')
        expect( result[:err_msg] ).to match(/Key retrieval failed/)
        FileUtils.chmod(0770, File.dirname(key_file))
      end
    end

    describe 'list' do
    end

    describe 'name' do
    end

    describe 'put' do
    end

  end

end
