require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet'
require 'simp/rspec-puppet-facts'
include Simp::RspecPuppetFacts

require 'pathname'

# RSpec Material
fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))
module_name = File.basename(File.expand_path(File.join(__FILE__,'../..')))

if !ENV.key?( 'TRUSTED_NODE_DATA' )
  warn '== WARNING: TRUSTED_NODE_DATA is unset, using TRUSTED_NODE_DATA=yes'
  ENV['TRUSTED_NODE_DATA']='yes'
end

default_hiera_config =<<-EOM
---
version: 5
hierarchy:
  - name: SIMP Compliance Engine
    lookup_key: compliance_markup::enforcement
  - name: Custom Test Hiera
    path: "%{custom_hiera}.yaml"
  - name: "%{module_name}"
    path: "%{module_name}.yaml"
  - name: Common
    path: default.yaml
defaults:
  data_hash: yaml_data
  datadir: "stub"
EOM

# This can be used from inside your spec tests to set the testable environment.
# You can use this to stub out an ENC.
#
# Example:
#
# context 'in the :foo environment' do
#   let(:environment){:foo}
#   ...
# end
#
def set_environment(environment = :production)
  RSpec.configure { |c| c.default_facts['environment'] = environment.to_s }
end

# This can be used from inside your spec tests to load custom hieradata within
# any context.
#
# Example:
#
# describe 'some::class' do
#   context 'with version 10' do
#     let(:hieradata){ "#{class_name}_v10" }
#     ...
#   end
# end
#
# Then, create a YAML file at spec/fixtures/hieradata/some__class_v10.yaml.
#
# Hiera will use this file as it's base of information stacked on top of
# 'default.yaml' and <module_name>.yaml per the defaults above.
#
# Note: Any colons (:) are replaced with underscores (_) in the class name.
def set_hieradata(hieradata)
  RSpec.configure { |c| c.default_facts['custom_hiera'] = hieradata }
end

if not File.directory?(File.join(fixture_path,'hieradata')) then
  FileUtils.mkdir_p(File.join(fixture_path,'hieradata'))
end

if not File.directory?(File.join(fixture_path,'modules',module_name)) then
  FileUtils.mkdir_p(File.join(fixture_path,'modules',module_name))
end

RSpec.configure do |c|
  # If nothing else...
  c.default_facts = {
    :production => {
      #:fqdn           => 'production.rspec.test.localdomain',
      :path           => '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin',
      :concat_basedir => '/tmp'
    }
  }

  c.trusted_server_facts = true

  c.mock_framework = :rspec
  c.mock_with :mocha

  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests')

  c.hiera_config = File.join(fixture_path,'hieradata','hiera.yaml')

  # Useless backtrace noise
  backtrace_exclusion_patterns = [
    /spec_helper/,
    /gems/
  ]

  if c.respond_to?(:backtrace_exclusion_patterns)
    c.backtrace_exclusion_patterns = backtrace_exclusion_patterns
  elsif c.respond_to?(:backtrace_clean_patterns)
    c.backtrace_clean_patterns = backtrace_exclusion_patterns
  end

  c.before(:all) do
    data = YAML.load(default_hiera_config)
    data.keys.each do |key|
      next unless data[key].is_a?(Hash)

      if data[key][:datadir] == 'stub'
        data[key][:datadir] = File.join(fixture_path, 'hieradata')
      elsif data[key]['datadir'] == 'stub'
        data[key]['datadir'] = File.join(fixture_path, 'hieradata')
      end
    end

    File.open(c.hiera_config, 'w') do |f|
      f.write data.to_yaml
    end
  end

  c.before(:each) do
    @spec_global_env_temp = Dir.mktmpdir('simpspec')

    if defined?(environment)
      set_environment(environment)
      FileUtils.mkdir_p(File.join(@spec_global_env_temp,environment.to_s))
    end

    # ensure the user running these tests has an accessible environmentpath
    Puppet[:environmentpath] = @spec_global_env_temp
    Puppet[:user] = Etc.getpwuid(Process.uid).name
    Puppet[:group] = Etc.getgrgid(Process.gid).name

    # sanitize hieradata
    if defined?(hieradata)
      set_hieradata(hieradata.gsub(':','_'))
    elsif defined?(class_name)
      set_hieradata(class_name.gsub(':','_'))
    end
=begin
    ########## CUSTOM ##########
FIXME: re-enable when consul tests are fixed
    `curl -sX DELETE http://172.17.0.1:10500/v1/kv/puppet?recurse`
    `curl -sX DELETE http://172.17.0.1:10504/v1/kv/puppet?recurse`
=end
  end

  c.after(:each) do
    # clean up the mocked environmentpath
    FileUtils.rm_rf(@spec_global_env_temp)
    @spec_global_env_temp = nil
  end
end

Dir.glob("#{RSpec.configuration.module_path}/*").each do |dir|
  begin
    Pathname.new(dir).realpath
  rescue
    fail "ERROR: The module '#{dir}' is not installed. Tests cannot continue."
  end
end

########## CUSTOM ##########
def datatype_testspec
  [
    # Test Number
    {
      :key => 'test_number',
      :value => 255,
      :nonserial_retval => '255',
      :nonserial_class => 'String',
      :class => 'Integer',
      :puppet_type => 'Integer',
    },
    # Test String
    {
      :key => 'test_string',
      :value => 'test1',
      :nonserial_retval => 'test1',
      :nonserial_class => 'String',
      :class => 'String',
      :puppet_type => 'String',
    },
    # Test Boolean
    {
      :key => 'test_boolean',
      :value => true,
      :nonserial_retval => 'true',
      :nonserial_class => 'String',
      :class => 'TrueClass',
      :puppet_type => 'Boolean',
    },
=begin
    # Test Float
    {
      :key => 'test_float',
      :value => 2.38490,
      :nonserial_retval => '2.3849',
      :nonserial_class => 'String',
      :class => 'Float',
      :puppet_type => 'Float',
    },
    # Test Array
    {
      :key => 'test_array',
      :value => ['test3', 'test4'],
      :nonserial_retval => '["test3", "test4"]',
      :nonserial_class => 'String',
      :class => 'Array',
      :puppet_type => 'Array',
    },
    # Test Hash
    {
      :key => 'test_hash',
      :value => {'key' => 'test', 'value' => 'test2'},
      :nonserial_retval => '{"key"=>"test", "value"=>"test2"}',
      :nonserial_class => 'String',
      :class => 'Hash',
      :puppet_type => 'Hash',
    },
=end
  ]
end

def providers()
  path = File.join(File.dirname(__FILE__), 'support')
  [
    {
      'name'      => 'mock with serialize false',
      'url'       => 'mock://',
      'serialize' => false,
    },
    {
      'name' => 'mock with serialize true and mode is unset',
      'url' => 'mock://',
      'serialize' => true,
    },
    # {
    # 'name' => "mock with serialize true and mode is 'native'",
    # 'url' => 'mock://',
    #         'serialize' => true,
    # 'mode' => 'native',
    # },
=begin
FIXME: re-enable when consul tests are fixed
    {
        'name' => 'consul with serialize false and with daemon',
        'url' => 'consul://172.17.0.1:10500/puppet',
        'serialize' => false,
        'softfail' => false,
        'should_error' => false,
    },
    {
        'name' => 'consul with serialize true and mode is unset and with daemon',
        'url' => 'consul://172.17.0.1:10500/puppet',
        'serialize' => true,
        'softfail' => false,
        'should_error' => false,
    },
    # {
    #   'name' => "consul with serialize true and mode is 'native' and with daemon",
    #   'url' => 'consul://172.17.0.1:8500/puppet',
    #   'serialize' => true,
    #   'mode' => 'native',
    #   'softfail' => false,
    #   'should_error' => false,
    #  },
    {
        'name' => 'consul with ssl and without auth and with daemon and multiple path segments',
        'url' => 'consul+ssl+noverify://172.17.0.1:10501/puppet/default/',
        'serialize' => true,
        'softfail' => false,
        'should_error' => false,
    },
    {
#FIXME  This looks identical to the previous
        'name' => 'consul with ssl and without auth and with daemon',
        'url' => 'consul+ssl+noverify://172.17.0.1:10501/puppet',
        'serialize' => true,
        'softfail' => false,
        'should_error' => false,
    },
    {
        'name' => 'consul with ssl and with server verification and with daemon',
        'url' => 'consul+ssl+verify://172.17.0.1:10501/puppet',
        'auth' => {
            'ca_file' => "#{path}/test/ca.crt",
        },
        'serialize' => true,
        'softfail' => false,
        'should_error' => false,
    },
    {
      'name' => 'consul with ssl and with server verification and certificate auth and with daemon',
      'url' => 'consul+ssl+verify://172.17.0.1:10503/puppet',
      'auth' => {
        'ca_file' => "#{path}/test/ca.crt",
        'cert_file' => "#{path}/test/server.crt",
        'key_file' => "#{path}/test/server.key",
      },
      'serialize' => true,
      'softfail' => false,
      'should_error' => false,
    },
#    {
#      'name' => 'consul without daemon and softfail = false',
#      'url' => 'consul://172.17.0.1:8500/puppet',
#      'softfail' => false,
#      'should_error' => true,
#    },
#    {
#      'name' => 'consul without daemon and softfail = true',
#      'url' => 'consul://172.17.0.1:8500/puppet',
#      'softfail' => true,
#      'should_error' => false,
#    },
=end
  ]
end

