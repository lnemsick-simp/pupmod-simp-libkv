require 'spec_helper'

require 'fileutils'
require 'tmpdir'

# mimic loading that is done in libkv.rb
project_dir = File.join(File.dirname(__FILE__), '..', '..', '..', '..')
plugin_file = File.join(project_dir, 'lib', 'puppet_x', 'libkv', 'file_plugin.rb')
plugin_class = nil
obj = Object.new
obj.instance_eval(File.read(plugin_file), plugin_file)

def locked_key_file_operation(root_path, key, value, &block)
  # create the file to be locked
  key_file = File.join(root_path, key)
  File.open(key_file, 'w') { |file| file.write(value) }

  locker_thread = nil   # thread that will lock the file
  mutex = Mutex.new
  locked = ConditionVariable.new
  begin
    locker_thread = Thread.new do
      puts "     >> Locking key file #{key_file}"
      file = File.open(key_file, 'r')
      file.flock(File::LOCK_EX)

      # signal the lock has taken place
      mutex.synchronize { locked.signal }

      # pause the thread until we are done our access attempt
      Thread.stop
      file.close
      puts '     >> Lock released with close'
    end


    # wait for the thread to signal the lock has taken place
    mutex.synchronize { locked.wait(mutex) }

    # exercise the accessor
    block.call

  ensure
    if locker_thread
      # wait until thread has paused
      sleep 0.5 while locker_thread.status != 'sleep'

      # resume and then wait until thread completed
      locker_thread.run
      locker_thread.join
    end
  end

end

describe 'libkv file plugin anonymous class' do
  before(:each) do
    @tmpdir = Dir.mktmpdir
    @root_path = File.join(@tmpdir, 'libkv', 'file')
    @options = {
      'backend'  => 'test',
      'backends' => {
        'test'  => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path,
          'lock_timeout_seconds' => 1
        }
      }
    }
    allow(FileUtils).to receive(:rm_r).with(any_args).and_call_original
    allow(File).to receive(:open).with(any_args).and_call_original
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  context 'type' do
    it "class.type should return 'file'" do
      expect(plugin_class.type).to eq 'file'
    end
  end

  context 'constructor' do
    context 'success cases' do
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


      it 'should fail when root path cannot be created' do
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

      it 'should fail when root path permissions cannot be set' do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test'  => {
              'id'        => 'test',
              'type'      => 'file',
              'root_path' => @root_path,
              'user'      => 'puppet',
              'group'     => 'puppet'
            }
          }
        }

        allow(FileUtils).to receive(:chmod).with(0750, @root_path).
          and_raise(Errno::EACCES, 'Permission denied')

        expect { plugin_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test Error: Unable to set permissions .* Permission denied/)
      end

      it 'should fail when root path ownership cannot be set' do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test'  => {
              'id'        => 'test',
              'type'      => 'file',
              'root_path' => @root_path,
              'user'      => 'puppet',
              'group'     => 'puppet'
            }
          }
        }

        allow(FileUtils).to receive(:chown).with('puppet', 'puppet', @root_path).
          and_raise(Errno::EACCES, 'Permission denied')

        expect { plugin_class.new('file/test', options) }.
          to raise_error(/libkv plugin file\/test Error: Unable to set permissions .* Permission denied/)
      end

    end
  end

  context 'public API' do
    before(:each) do
      @plugin = plugin_class.new('file/test', @options)
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

      it 'should return :result=false and an :err_msg when the key is a dir not a file' do
        keydir = 'keydir'
        FileUtils.mkdir_p(File.join(@root_path, keydir))
        result = @plugin.delete(keydir)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Key specifies a folder/)
      end

      it 'should return :result=false and an :err_msg when the key file delete fails' do
        key_file = File.join(@root_path, 'key1')
        allow(File).to receive(:unlink).with(key_file).
          and_raise(Errno::EACCES, 'Permission denied')

        result = @plugin.delete('key1')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Delete failed:/)
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
        key_dir = File.join(@root_path, 'production/gen_passwd')
        FileUtils.mkdir_p(key_dir)
        allow(FileUtils).to receive(:rm_r).with(key_dir).
          and_raise(Errno::EACCES, 'Permission denied')

        result = @plugin.deletetree('production/gen_passwd')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Folder delete failed:/)
      end
    end

    describe 'exists' do
      it 'should return :result=false when the key file does not exist or is inaccessible' do
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

      it 'should return unset :result and an :err_msg when the key is a dir not a file' do
        keydir = 'keydir'
        FileUtils.mkdir_p(File.join(@root_path, keydir))
        result = @plugin.get(keydir)
        expect( result[:result] ).to be_nil
        expect( result[:err_msg] ).to match(/Key specifies a folder/)
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
        allow(File).to receive(:open).with(key_file, 'r').
          and_raise(Errno::EACCES, 'Permission denied')
        result = @plugin.get('production/key1')
        expect( result[:result] ).to be_nil
        expect( result[:err_msg] ).to match(/Key retrieval failed/)
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

      it 'should return an unset :result  and an :err_msg when key folder does not exist or is inaccessible' do
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
        key_file = File.join(@root_path, key)
        expect( File.stat(key_file).mode & 0777 ).to eq 0640
      end

      it 'should return :result=true when the key file does not exist for a complex key' do
        key = 'production/gen_passwd/key1'
        value = 'value for key1'
        result = @plugin.put(key, value)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
        expect( @plugin.get(key)[:result] ).to eq value
        key_file = File.join(@root_path, key)
        expect( File.stat(key_file).mode & 0777 ).to eq 0640
        expect( File.stat(File.join(@root_path, 'production')).mode & 0777 ).to eq 0750
        expect( File.stat(File.join(@root_path, 'production', 'gen_passwd')).mode & 0777 ).to eq 0750
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

      it 'should return :result=false an an :err_msg when the key file cannot be created' do
        key_file = File.join(@root_path, 'key')
        allow(File).to receive(:open).with(key_file, File::RDWR|File::CREAT, 0640).
          and_raise(Errno::EACCES, 'Permission denied')

        result = @plugin.put('key', 'value')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Key write failed/)
      end
    end
  end

end
