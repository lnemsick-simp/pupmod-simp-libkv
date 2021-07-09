require 'spec_helper'

require 'fileutils'
require 'tmpdir'

# mimic loading that is done in loader.rb, but be sure to load what is in
# the fixtures dir
project_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'spec', 'fixtures', 'modules', 'simpkv'))
simpkv_adapter_file = File.join(project_dir, 'lib', 'puppet_x', 'simpkv', 'simpkv.rb')
simp_simpkv_adapter_class = nil
obj = Object.new
obj.instance_eval(File.read(simpkv_adapter_file), simpkv_adapter_file)


describe 'simpkv adapter anonymous class' do

  # tell puppet-rspec to set Puppet environment to 'production'
  let(:environment) {'production'}

  # Going to use file plugin and the test plugins in spec/support/test_plugins
  # for these unit tests.
  before(:each) do
    # set up configuration for the file plugin
    @tmpdir = Dir.mktmpdir
    @root_path = File.join(@tmpdir, 'simpkv', 'file')
    options_base = {
      'environment' => environment,
      'backends'    => {
        # will use failer plugin for catastrophic error cases, because
        # it is badly behaved and raises exceptions on all operations
       'test_failer'  => {
          'id'             => 'test',
          'type'           => 'failer',
          'fail_configure' => false  # true = raise in configure()
        },
        # will use file plugin for non-catastrophic test cases
        'test_file'  => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path
        }
      }
    }
    @options_file   = options_base.merge ({ 'backend' => 'test_file' } )
    @options_failer = options_base.merge ({ 'backend' => 'test_failer' } )
    @options_failer_ctr = {
      'backend'  => 'test_failer',
      'backends' => {
        'test_failer'  => {
          'id'             => 'test',
          'type'           => 'failer',
          'fail_configure' => true  # true = raise in constructor
        }
      }
    }
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end


  context 'constructor' do
    it 'should load valid plugin classes' do
      expect{ simp_simpkv_adapter_class.new }.to_not raise_error
      adapter = simp_simpkv_adapter_class.new
      expect( adapter.plugin_info ).to_not be_empty
      expect( adapter.plugin_info.keys.include?('file') ).to be true
      expect( adapter.plugin_info.keys.include?('failer') ).to be true
      expect( adapter.plugin_info.keys.include?('malformed') ).to be false
    end

    it 'should discard a plugin class with malformed Ruby' do
      allow(Puppet).to receive(:warning)
      adapter = simp_simpkv_adapter_class.new
      expect(Puppet).to have_received(:warning).with(/simpkv plugin from .*malformed_plugin.rb failed to load/)
    end
  end

  context 'helper methods' do
    before(:each) do
      @adapter = simp_simpkv_adapter_class.new
    end

    context '#filter_backtrace' do
      it 'should filter-out backtrace lines containing Puppet library internals' do
        # this is not even the full backtrace (~150 lines), but is good enough for testing
        full_backtrace = [
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet_x/simpkv/file_plugin.rb:379:in `ensure_root_path'",
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet_x/simpkv/simpkv.rb:394:in `plugin_instance'",
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet_x/simpkv/simpkv.rb:280:in `put'",
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet/functions/simpkv/put.rb:131:in `put'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/functions/dispatch.rb:60:in `invoke'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/functions/dispatcher.rb:43:in `block in dispatch'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/functions/dispatcher.rb:42:in `catch'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/functions/dispatcher.rb:42:in `dispatch'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/functions/function.rb:46:in `block in call'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/functions/function.rb:45:in `catch'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/functions/function.rb:45:in `call'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/pops/puppet_stack.rb:42:in `stack'",
          # skip a bunch of lines
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/application.rb:382:in `run'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/util/command_line.rb:143:in `run'",
          "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/util/command_line.rb:77:in `execute'",
          "/opt/puppetlabs/puppet/bin/puppet:5:in `<main>'",
        ]

        expected = [
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet_x/simpkv/file_plugin.rb:379:in `ensure_root_path'",
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet_x/simpkv/simpkv.rb:394:in `plugin_instance'",
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet_x/simpkv/simpkv.rb:280:in `put'",
          "/etc/puppetlabs/code/environments/production/modules/simpkv/lib/puppet/functions/simpkv/put.rb:131:in `put'",
        ]

        expect( @adapter.filter_backtrace(full_backtrace) ).to eq(expected)
      end
    end

    context '#normalize_key' do
      let(:key) { 'my/test/key' }
      let(:normalized_env_key) { 'environments/production/my/test/key' }
      let(:normalized_global_key) { 'globals/my/test/key' }

      context 'with operation=:add_prefix (default)' do
        it "should add the env path when only 'environment' option is specified" do
          opts = {'environment' => 'production'}
          expect( @adapter.normalize_key(key, opts) ).to eq normalized_env_key
        end

        it "should add the env path when 'global'=false and 'environment' is set" do
          opts = {'environment' => 'production', 'global' => false}
          expect( @adapter.normalize_key(key, opts) ).to eq normalized_env_key
        end

        it "should add the global path when 'global' is true" do
          opts = {'environment' => 'production', 'global' => true}
          expect( @adapter.normalize_key(key, opts) ).to eq normalized_global_key
        end
      end

      context 'with operation=:remove_prefix' do
        it "should remove the env path when only 'environment' option is specified" do
          opts = {'environment' => 'production'}
          expect( @adapter.normalize_key(normalized_env_key, opts, :remove_prefix) ).to eq key
        end

        it "should remove the env path when 'global'=false and 'environment' is set" do
          opts = {'environment' => 'production', 'global' => false}
          expect( @adapter.normalize_key(normalized_env_key, opts, :remove_prefix) ).to eq key
        end

        it "should remove the global path when 'global' is true" do
          opts = {'environment' => 'production', 'global' => true}
          expect( @adapter.normalize_key(normalized_global_key, opts, :remove_prefix) ).to eq key
        end
      end
    end

    context '#plugin_instance' do
      context 'success cases' do
        it 'should create an instance when config is correct' do
          instance = @adapter.plugin_instance(@options_file)

          file_class_id = @adapter.plugin_info['file'][:class].to_s
          expect( instance.name ).to eq 'file/test'
          expect( instance.to_s ).to match file_class_id
        end

        it 'should retrieve an existing instance' do
          instance1 = @adapter.plugin_instance(@options_file)
          instance1_id = instance1.to_s

          instance2 = @adapter.plugin_instance(@options_file)
          expect(instance1_id).to eq(instance2.to_s)
        end
      end

      context 'error cases' do
        it 'should fail when options is not a Hash' do
          expect { @adapter.plugin_instance('oops') }.
            to raise_error(/Malformed backend config/)
        end

        it "should fail when options missing 'backend' key" do
          expect { @adapter.plugin_instance({}) }.
            to raise_error(/Malformed backend config/)
        end

        it "should fail when options missing 'backends' key" do
          options = {
            'backend' => 'test'
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/Malformed backend config/)
        end

        it "should fail when options 'backends' key is not a Hash" do
          options = {
            'backend'  => 'test',
            'backends' => 'oops'
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/Malformed backend config/)
        end

        it "should fail when options 'backends' does not have the specified backend" do
          options = {
            'backend'  => 'test',
            'backends' => {
              'test1' => { 'id' => 'test', 'type' => 'consul'}
            }
          }
          expect { @adapter.plugin_instance(options) }.
            to raise_error(/Malformed backend config/)
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
            to raise_error(/Malformed backend config/)
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
            to raise_error(/Malformed backend config/)
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
            to raise_error(/Malformed backend config/)
        end


        it 'should fail when plugin instance cannot be created' do

          expect { @adapter.plugin_instance(@options_failer_ctr) }.
            to raise_error(/Unable to construct 'failer\/test'/)
        end
      end
    end
  end

  context 'serialization operations' do
    before(:each) do
      @adapter = simp_simpkv_adapter_class.new
    end

    context '#serialize and #serialize_string_value' do
      data_info.each do |summary,info|
        it "should properly serialize a #{summary}" do
          skip info[:skip] if info.has_key?(:skip)
          expect( @adapter.serialize(info[:value], info[:metadata]) ).
            to eq info[:serialized_value]
        end
      end
    end

    context '#deserialize and #deserialize_string_value' do
      data_info.each do |summary,info|
        it "should properly deserialize a #{summary}" do
          skip info[:skip] if info.has_key?(:skip)
          expected = info.has_key?(:deserialized_value) ? info[:deserialized_value] : info[:value]
          expect( @adapter.deserialize(info[:serialized_value]) ).
            to eq({ :value => expected, :metadata => info[:metadata] })
        end
      end

      it 'should fail when input is not in JSON format' do
        expect{ @adapter.deserialize('this is not JSON')}. to raise_error(
          RuntimeError, /Failed to deserialize: JSON parse error/)
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
  end

  context 'public API' do
    before(:each) do
      @adapter = simp_simpkv_adapter_class.new

      # create our own file plugin instance so we can manipulate key/store
      # independent of the simpkv adapter
      @plugin = @adapter.plugin_info['file'][:class].new('other')
      @plugin.configure(@options_file)
    end

    let(:key) { 'my/test/key' }
    let(:key_plus_env) { 'environments/production/my/test/key' }
    let(:value) { 'some string' }
    let(:metadata) { { 'foo' => 'bar' } }
    let(:serialized_value) {
      '{"value":"some string","metadata":{"foo":"bar"}}'
    }

    context '#backends' do
      it 'should list available backend plugins' do
        # currently only 2 plugins (one real and one for test only)
        expect( @adapter.backends ).to eq([ 'failer', 'file' ])
      end
    end

    context '#delete' do
      it 'should return plugin delete result' do
        @plugin.put(key_plus_env, serialized_value)
        expect(@adapter.delete(key, @options_file)).
          to eq({:result => true, :err_msg => nil})

        expect(@plugin.exists(key_plus_env)).
          to eq({:result => false, :err_msg => nil})
      end

      it 'should return a failed result when plugin instance cannot be created' do
        result = @adapter.delete(key, @options_failer_ctr)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/simpkv Error: Unable to construct 'failer\/test'/)
      end

      it 'should fail when plugin delete raises an exception' do
        result = @adapter.delete(key, @options_failer)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/simpkv failer\/test Error: delete catastrophic failure/)
      end
    end

    context '#deletetree' do
      let(:keydir) { key.gsub('/key','') }
      it 'should return plugin deletetree result' do
        @plugin.put(key_plus_env, serialized_value)
        expect(@adapter.deletetree(keydir, @options_file)).
          to eq({:result => true, :err_msg => nil})

        expect(@plugin.exists(key_plus_env)).
          to eq({:result => false, :err_msg => nil})
      end

      it 'should return a failed result when plugin instance cannot be created' do
        result = @adapter.deletetree(keydir, @options_failer_ctr)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/simpkv Error: Unable to construct 'failer\/test'/)
      end

      it 'should fail when plugin deletetree raises an exception' do
        result = @adapter.deletetree(keydir, @options_failer)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/simpkv failer\/test Error: deletetree catastrophic failure/)
      end
    end

    context '#exists' do
      it 'should return plugin exists result for a key' do
        @plugin.put(key_plus_env, serialized_value)
        expect(@adapter.exists(key, @options_file)).
          to eq({:result => true, :err_msg => nil})
      end

      it 'should return plugin exists result for a keydir' do
        @plugin.put(key_plus_env, serialized_value)
        expect(@adapter.exists(File.dirname(key), @options_file)).
          to eq({:result => true, :err_msg => nil})
      end

      it 'should return a failed result when plugin instance cannot be created' do
        result = @adapter.exists(key, @options_failer_ctr)
        expect( result[:result] ).to be nil
        expect( result[:err_msg] ).to match(/simpkv Error: Unable to construct 'failer\/test'/)
      end

      it 'should fail when plugin exists raises an exception' do
        result = @adapter.exists(key, @options_failer)
        expect( result[:result] ).to be nil
        expect( result[:err_msg] ).to match(/simpkv failer\/test Error: exists catastrophic failure/)
      end
    end

    context '#get' do
      it 'should return deserialized plugin get result' do
        @plugin.put(key_plus_env, serialized_value)
        expect(@adapter.get(key, @options_file)).
          to eq({
            :result => {:value => value, :metadata => metadata},
            :err_msg => nil
          })
      end

      it 'should return a failed result when deserialization of plugin get result fails' do
        @plugin.put(key_plus_env, 'This is not JSON')
        result = @adapter.get(key, @options_file)
        expect( result.fetch(:result) ).to be_nil
        expect( result[:err_msg] ).to match(/simpkv file\/test Error: Failed to deserialize/)
      end

      it 'should return a failed result when plugin instance cannot be created' do
        result = @adapter.get(key, @options_failer_ctr)
        expect( result[:result] ).to be nil
        expect( result[:err_msg] ).to match(/simpkv Error: Unable to construct 'failer\/test'/)
      end

      it 'should fail when plugin get raises an exception' do
        result = @adapter.get(key, @options_failer)
        expect( result[:result] ).to be nil
        expect( result[:err_msg] ).to match(/simpkv failer\/test Error: get catastrophic failure/)
      end
    end

    context '#list' do
      let(:keydir) { key.gsub('/key','') }
      it 'should return deserialized plugin list result' do
        @plugin.put(key_plus_env, serialized_value)
        # create a sub-folder
        @plugin.put(key_plus_env.gsub('/key', '/app1/key'), serialized_value)
        expect(@adapter.list(keydir, @options_file)).
          to eq({
            :result => {
              :keys => {
                File.basename(key) => {:value => value, :metadata => metadata},
              },
              :folders => [ 'app1' ]
            },
            :err_msg => nil
          })
      end

      it "should return list of top level folders for the environment when passed '/' as the key" do
        @plugin.put(key_plus_env, serialized_value)
        expect(@adapter.list('/', @options_file)).
          to eq({
            :result => {
              :keys => {},
              :folders => [ 'my' ]
            },
            :err_msg => nil
          })
      end

      it "should return list of environments when passed '/' as the key and environment is set to ''" do
        @plugin.put(key_plus_env, serialized_value)
        options = @options_file.dup
        options['environment'] =''
        expect(@adapter.list('/', options)).
          to eq({
            :result => {
              :keys => {},
              :folders => [ 'production' ]
            },
            :err_msg => nil
          })
      end

      it 'should return a failed result when deserialization of plugin list result fails' do
        @plugin.put(key_plus_env, 'This is not JSON')
        result = @adapter.list(keydir, @options_file)
        expect( result.fetch(:result) ).to be_nil
        expect( result[:err_msg] ).to match(/simpkv file\/test Error: Failed to deserialize/)
      end

      it 'should return a failed result when plugin instance cannot be created' do
        result = @adapter.list(keydir, @options_failer_ctr)
        expect( result[:result] ).to be nil
        expect( result[:err_msg] ).to match(/simpkv Error: Unable to construct 'failer\/test'/)
      end

      it 'should fail when plugin list raises an exception' do
        result = @adapter.list(keydir, @options_failer)
        expect( result[:result] ).to be nil
        expect( result[:err_msg] ).to match(/simpkv failer\/test Error: list catastrophic failure/)
      end
    end

    context '#put' do
      it 'should return plugin put result' do
        expect(@adapter.put(key, value, metadata, @options_file)).
          to eq({:result => true, :err_msg => nil})

        expect(@plugin.exists(key_plus_env)).
          to eq({:result => true, :err_msg => nil})
      end

      it 'should return a failed result when plugin instance cannot be created' do
        result = @adapter.put(key, value, metadata, @options_failer_ctr)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/simpkv Error: Unable to construct 'failer\/test'/)
      end

      it 'should fail when plugin put raises an exception' do
        result = @adapter.put(key, value, metadata, @options_failer)
        expect( result[:result] ).to be false
        expect( result[:err_msg] ).to match(/simpkv failer\/test Error: put catastrophic failure/)
      end
    end
  end

end
