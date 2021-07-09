require 'spec_helper'

require 'fileutils'
require 'tmpdir'
require 'ostruct'

# mimic loading that is done in simpkv.rb
project_dir = File.join(File.dirname(__FILE__), '..', '..', '..', '..')
plugin_file = File.join(project_dir, 'lib', 'puppet_x', 'simpkv', 'file_plugin.rb')
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

describe 'simpkv file plugin anonymous class' do
  before(:each) do
    @tmpdir = Dir.mktmpdir
    @root_path = File.join(@tmpdir, 'simpkv', 'file')
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

    @plugin_name = 'file/test'
    allow(Dir).to receive(:exist?).with(any_args).and_call_original
    allow(FileUtils).to receive(:chmod).with(any_args).and_call_original
    allow(FileUtils).to receive(:mkdir_p).with(any_args).and_call_original
    allow(FileUtils).to receive(:rm_r).with(any_args).and_call_original
    allow(File).to receive(:open).with(any_args).and_call_original
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  context 'configure' do
    before(:each) do
      @plugin = plugin_class.new(@plugin_name)
    end

    context 'success cases' do
      it 'should create the root_path tree when none exists' do
        expect{ @plugin.configure(@options) }.to_not raise_error
        expect( Dir.exist?(@root_path) ).to be true
        expect( Dir.exist?(File.join(@root_path, 'globals')) ).to be true
        expect( Dir.exist?(File.join(@root_path, 'environments')) ).to be true
      end

      it 'should not fail if the root_path tree exists' do
        FileUtils.mkdir_p(@root_path)
        expect{ @plugin.configure(@options) }.to_not raise_error
      end
    end

    context 'error cases' do
      it 'should fail when options is not a Hash' do
        expect { @plugin.configure('oops') }.
          to raise_error(/Plugin misconfigured/)
      end

      it "should fail when options missing 'backend' key" do
        expect { @plugin.configure({}) }.
          to raise_error(/Plugin misconfigured/)
      end

      it "should fail when options missing 'backends' key" do
        options = {
          'backend' => 'test'
        }
        expect { @plugin.configure({}) }.
          to raise_error(/Plugin misconfigured: {}/)
      end

      it "should fail when options 'backends' key is not a Hash" do
        options = {
          'backend'  => 'test',
          'backends' => 'oops'
        }
        expect { @plugin.configure(options) }.
          to raise_error(/Plugin misconfigured/)
      end

      it "should fail when options 'backends' does not have the specified backend" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'}
          }
        }
        expect { @plugin.configure(options) }.
          to raise_error(/Plugin misconfigured/)
      end

      it "should fail when the correct 'backends' element has no 'id' key" do
        options = {
          'backend' => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'},
            'test'  => {}
          }
        }
        expect { @plugin.configure(options) }.
          to raise_error(/Plugin misconfigured/)
      end

      it "should fail when the correct 'backends' element has no 'type' key" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'},
            'test'  => { 'id' => 'test' }
          }
        }
        expect { @plugin.configure(options) }.
          to raise_error(/Plugin misconfigured/)
      end

      it "should fail when the correct 'backends' element has wrong 'type' value" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'consul'},
            'test'  => { 'id' => 'test', 'type' => 'filex' }
          }
        }
        expect { @plugin.configure(options) }.
          to raise_error(/Plugin misconfigured/)
      end


      it 'should fail when configured root path cannot be created' do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test'  => {
              'id'        => 'test',
              'type'      => 'file',
              'root_path' => '/can/not/be/created'
            }
          }
        }

        allow(Dir).to receive(:exist?).with('/can/not/be/created').and_return( false )
        allow(FileUtils).to receive(:mkdir_p).with('/can/not/be/created').
          and_raise(Errno::EACCES, 'Permission denied')

        expect { @plugin.configure(options) }.
          to raise_error(/Unable to create configured root path/)
      end
    end
  end

  context 'public simpkv operations API' do
    before(:each) do
      @plugin = plugin_class.new(@plugin_name)
      @plugin.configure(@options)
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
        expect( result[:err_msg] ).to match(/Delete of '.*' failed:/)
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
        expect( result[:err_msg] ).to match(/Folder delete of '.*' failed:/)
      end
    end

    describe 'exists' do
      it 'should return :result=false when the key does not exist or is inaccessible' do
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

      it 'should return :result=true when the key folder exists and is accessible' do
        key_folder = File.join(@root_path, 'app1')
        FileUtils.mkdir_p(key_folder)
        result = @plugin.exists('app1')
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
          expect( result[:err_msg] ).to match /Timed out waiting for lock of key file/
        end

        # just to be sure lock is appropriately cleared...
        result = @plugin.get(key)
        expect( result[:result] ).to_not be_nil
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return an unset :result and an :err_msg when the key file exists but is not accessible' do
        # mock a key file that is inaccessible
        key_file = File.join(@root_path, 'production/key1')
        allow(File).to receive(:open).with(key_file, 'r').
          and_raise(Errno::EACCES, 'Permission denied')
        result = @plugin.get('production/key1')
        expect( result[:result] ).to be_nil
        expect( result[:err_msg] ).to match(/Cannot read '#{Regexp.escape(key_file)}'/)
      end
    end

    # using plugin's put() in this test, because it is fully tested below
    describe 'list' do

      it 'should return an empty :result when key folder is empty' do
        key_dir = File.join(@root_path, 'production')
        FileUtils.mkdir_p(key_dir)
        result = @plugin.list('production')
        expect( result[:result] ).to eq({ :keys => {}, :folders => []})
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return full list of key/value pairs and sub-folders in :result when key folder content is accessible' do
        expected = {
          :keys => {
            'key1' => 'value for key1',
            'key2' => 'value for key2',
            'key3' => 'value for key3'
          },
          :folders => [
            'app1',
            'app2'
          ]
        }
        expected[:keys].each { |key,value| @plugin.put("production/#{key}", value) }
        expected[:folders].each { |folder| @plugin.put("production/#{folder}/key", "#{folder}/key value") }
        result = @plugin.list('production')
        expect( result[:result] ).to eq(expected)
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return partial list of key/value pairs in :result when some key folder content is not accessible' do
        expected = {
          :keys => {
            'key1' => 'value for key1',
            'key3' => 'value for key3'
          },
          :folders => []
        }
        expected[:keys].each { |key,value| @plugin.put("production/#{key}", value) }

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
        expect( result[:err_msg] ).to match(/Key folder '.*' not found/)
      end
    end

    describe 'name' do
      it 'should return configured name' do
        expect( @plugin.name ).to eq @plugin_name
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
        expect( File.stat(key_file).mode & 0777 ).to eq 0660
      end

      it 'should return :result=true when the key file does not exist for a complex key' do
        key = 'production/gen_passwd/key1'
        value = 'value for key1'
        result = @plugin.put(key, value)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
        expect( @plugin.get(key)[:result] ).to eq value
        key_file = File.join(@root_path, key)
        expect( File.stat(key_file).mode & 0777 ).to eq 0660
        expect( File.stat(File.join(@root_path, 'production')).mode & 0777 ).to eq 0770
        expect( File.stat(File.join(@root_path, 'production', 'gen_passwd')).mode & 0777 ).to eq 0770
      end

      it 'should fix permissions and return :result=true when the key file exists '\
         'and is owned by user' do
        key = 'key1'
        key_file = File.join(@root_path, key)
        FileUtils.touch(key_file)
        FileUtils.chmod(0640, key_file)

        value1 = 'value for key1 which is longer than second value'
        value2 = 'second value for key1'
        value3 = 'third value for key1 which is longer than second value'
        @plugin.put(key, value1)
        expect( File.stat(key_file).mode & 0777 ).to eq 0660

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
          expect( result[:err_msg] ).to match /Timed out waiting for lock of key file/
        end

        # just to be sure lock is appropriately cleared...
        result = @plugin.put(key, value2)
        expect( result[:result] ).to be true
        expect( result[:err_msg] ).to be_nil
      end

      it 'should return :result=false an an :err_msg when the key file cannot be created' do
        key_file = File.join(@root_path, 'key')
        allow(File).to receive(:open).with(key_file, File::RDWR|File::CREAT).
          and_raise(Errno::EACCES, 'Permission denied')

        result = @plugin.put('key', 'value')
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/Cannot write to '#{Regexp.escape(key_file)}'/)
      end
    end
  end

  context 'internal methods' do
    before(:each) do
      @plugin = plugin_class.new(@plugin_name)
      @plugin.configure(@options)
    end

    describe 'ensure_folder_path' do
      it 'should create folder path with correct permissions when not present' do
        @plugin.ensure_folder_path('some/folder/path')
        [
          File.join(@root_path, 'some'),
          File.join(@root_path, 'some', 'folder'),
          File.join(@root_path, 'some', 'folder', 'path')
        ].each do |path|
          expect( Dir.exist?(path) ).to be true
          stat = File.stat(path)
          expect( stat.mode & 00777 ). to eq 0770
        end
      end

      it 'should create missing subdirs of folder path' do
        FileUtils.mkdir(File.join(@root_path, 'some'))
        @plugin.ensure_folder_path('some/folder/path')
        [
          File.join(@root_path, 'some', 'folder'),
          File.join(@root_path, 'some', 'folder', 'path')
        ].each do |path|
          expect( Dir.exist?(path) ).to be true
          stat = File.stat(path)
          expect( stat.mode & 00777 ). to eq 0770
        end
      end

      it 'should call verify_dir_access on existing subdirs of folder path' do
        FileUtils.mkdir_p(File.join(@root_path, 'some', 'folder', 'path'))
        allow(@plugin).to receive(:verify_dir_access).with(any_args).and_call_original
        [
          'some',
          File.join('some', 'folder'),
          File.join('some', 'folder', 'path')
        ].each do |path|
          expect(@plugin).to receive(:verify_dir_access).with(path).and_return(nil)
        end

        @plugin.ensure_folder_path('some/folder/path')
      end
    end

    describe 'ensure_root_path' do
      let(:options) { {
        'backend'  => 'test',
        'backends' => {
          'test'  => {
            'id'        => 'test',
            'type'      => 'file'
          }
        }
      } }

      context 'root_path config present' do
        it 'should return configured root_path and call verify_dir_access when root_path exists' do
          # @root_path was already created when @plugin was constructed
          expect(@plugin).to receive(:verify_dir_access).with(@root_path).and_return(nil)
          expect( @plugin.ensure_root_path(@options) ).to eq (@root_path)
        end

        it 'should return configured root_path and create the paths when it does not exists' do
          root_path = File.join(@tmpdir, 'file')
          opts = options.dup
          opts['backends']['test']['root_path'] = root_path
          expect( @plugin.ensure_root_path(opts) ).to eq (root_path)
          expect( Dir.exist?(root_path) ).to be true
          expect( File.stat(root_path).mode & 0777 ).to eq 0770
        end

        it 'should fail when configured root_path does not exist and cannot be created' do
          root_path = File.join(@tmpdir, 'file', 'test')
          opts = options.dup
          opts['backends']['test']['root_path'] = root_path
          allow(FileUtils).to receive(:mkdir_p).with(root_path)
            .and_raise(Errno::EACCES, 'Permission denied')

          expect{ @plugin.ensure_root_path(opts) }.to raise_error(
            /Unable to create configured root path/)
        end
      end

      context 'root_path config absent' do
        before :each do
          @vardir = File.join(@tmpdir, 'vardir')
          @default_path = File.join('/', 'var', 'simp', 'simpkv', @plugin_name)
          @fallback_path = File.join(@vardir, 'simp', 'simpkv', @plugin_name)
          allow(Puppet).to receive(:settings).with(any_args).and_call_original
          allow(Puppet).to receive_message_chain(:settings,:[]).with(:vardir).and_return(@vardir)
        end

        it 'should return default path in /var/simp and call verify_dir_access when path exists' do
          expect(Dir).to receive(:exist?).with(@default_path).and_return(true).twice
          expect(@plugin).to receive(:verify_dir_access).with(@default_path).and_return(nil)
          expect( @plugin.ensure_root_path(options) ).to eq (@default_path)
        end

        it 'should return fallback path in Puppet vardir and call '\
           'verify_dir_access when default path does not exist but fallback path does' do
          expect(Dir).to receive(:exist?).with(@default_path).and_return(false)
          expect(Dir).to receive(:exist?).with(@fallback_path).and_return(true).twice
          expect(@plugin).to receive(:verify_dir_access).with(@fallback_path).and_return(nil)
          expect( @plugin.ensure_root_path(options) ).to eq (@fallback_path)
        end

        it 'should create and return default path when neither default path exists' do
          expect(Dir).to receive(:exist?).with(@default_path).and_return(false).twice
          expect(Dir).to receive(:exist?).with(@fallback_path).and_return(false)
          expect(FileUtils).to receive(:mkdir_p).with(@default_path).and_return(nil)
          expect(FileUtils).to receive(:chmod).with(0770, @default_path).and_return(nil)
          expect( @plugin.ensure_root_path(options) ).to eq (@default_path)
        end

        it 'should create and return fallback path when neither default path exists '\
           'and primary default cannot be created' do
          expect(Dir).to receive(:exist?).with(@default_path).and_return(false).twice
          expect(Dir).to receive(:exist?).with(@fallback_path).and_return(false)
          expect(FileUtils).to receive(:mkdir_p).with(@default_path)
            .and_raise(Errno::EACCES, 'Permission denied')

          expect( @plugin.ensure_root_path(options) ).to eq (@fallback_path)
          expect( Dir.exist?(@fallback_path) ).to be true
          expect( File.stat(@fallback_path).mode & 0777 ).to eq 0770
        end

        it 'should fail when neither default path exists and neither can be created' do
          expect(Dir).to receive(:exist?).with(@default_path).and_return(false).twice
          expect(Dir).to receive(:exist?).with(@fallback_path).and_return(false)
          expect(FileUtils).to receive(:mkdir_p).with(@default_path)
            .and_raise(Errno::EACCES, 'Permission denied')

          expect(FileUtils).to receive(:mkdir_p).with(@fallback_path)
            .and_raise(Errno::EACCES, 'Permission denied')

          expect{ @plugin.ensure_root_path(options) }.to raise_error(
            /Unable to create default root path/)
        end
      end
    end

    describe 'verify_dir_access' do
      let(:dir) { 'some/folder/path' }
      before :each do
        allow(Dir).to receive(:entries).with(any_args).and_call_original
        allow(File).to receive(:stat).with(any_args).and_call_original
      end

      it 'should succeed when process user owns directory can read and modify it' do
        expect(Dir).to receive(:entries).with(dir).and_return([])
        mock_stat = OpenStruct.new
        mock_stat.uid = Process.uid
        mock_stat.gid = Process.gid
        mock_stat.mode = 00750
        expect(File).to receive(:stat).with(dir).and_return(mock_stat)
        expect(FileUtils).to receive(:chmod).with(0770, dir).and_return(nil)

        expect{ @plugin.verify_dir_access(dir) }.to_not raise_error
      end

      it 'should succeed when process group can read and modify a dir it does not own' do
        expect(Dir).to receive(:entries).with(dir).and_return([])

        mock_stat = OpenStruct.new
        mock_stat.uid = Process.uid + 1  # make sure there is a mismatch!
        mock_stat.gid = Process.gid
        mock_stat.mode = 00770
        expect(File).to receive(:stat).with(dir).and_return(mock_stat)

        allow(FileUtils).to receive(:chmod).with(0770, dir).and_return(nil)

        expect{ @plugin.verify_dir_access(dir) }.to_not raise_error
      end

      it 'should fail when directory cannot be read' do
        expect(Dir).to receive(:entries).with(dir).and_raise(
          Errno::EACCES, 'Permission denied')

        expect{ @plugin.verify_dir_access(dir) }.to raise_error(
          /Cannot access '#{Regexp.escape(dir)}'/)
      end

      it 'should fail process group cannot modify directory' do
        expect(Dir).to receive(:entries).with(dir).and_return([])

        mock_stat = OpenStruct.new
        mock_stat.uid = Process.uid + 1  # make sure there is a mismatch!
        mock_stat.gid = Process.gid
        mock_stat.mode = 00750
        expect(File).to receive(:stat).with(dir).and_return(mock_stat)

        expect{ @plugin.verify_dir_access(dir) }.to raise_error(
          /Cannot modify '#{Regexp.escape(dir)}'/)
      end
    end

  end

end
