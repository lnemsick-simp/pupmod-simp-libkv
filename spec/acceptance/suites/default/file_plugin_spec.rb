require 'spec_helper_acceptance'

test_name 'libkv file plugin'

describe 'libkv file plugin' do

  let(:hieradata) {{

    'libkv::backend::file_class' => {
      'type'      => 'file',
      'id'        => 'class',
      'root_path' => '/var/simp/libkv/file/class'
    },

    'libkv::backend::file_define_instance' => {
      'type'      => 'file',
      'id'        => 'define_instance',
      'root_path' => '/var/simp/libkv/file/define_instance'
    },

    'libkv::backend::file_define_type' => {
      'type'      => 'file',
      'id'        => 'define_type',
      'root_path' => '/var/simp/libkv/file/define_type'
    },

    'libkv::backend::file_default' => {
      'type'      => 'file',
      'id'        => 'default',
      'root_path' => '/var/simp/libkv/file/default'
    },

   'libkv::options' => {
      'environment' => '%{server_facts.environment}',
      'softfail'    => false,
      'backends' => {
      'default.Class[Libkv_test::Put]'            => "%{alias('libkv::backend::file_class')}",
      'default.Class[Libkv_test::Exists]'         => "%{alias('libkv::backend::file_class')}",
      'default.Class[Libkv_test::List]'           => "%{alias('libkv::backend::file_class')}",
      'default.Class[Libkv_test::Get]'            => "%{alias('libkv::backend::file_class')}",
      'default.Class[Libkv_test::Delete]'         => "%{alias('libkv::backend::file_class')}",
      'default.Class[Libkv_test::DeleteTree]'     => "%{alias('libkv::backend::file_class')}",
      'default.Libkv_test::Defines::Put[define2]' => "%{alias('libkv::backend::file_define_instance')}",
      'default.Libkv_test::Defines::Put'          => "%{alias('libkv::backend::file_define_type')}",
      'default'                                   => "%{alias('libkv::backend::file_default')}",
      }

    }

  }}

  hosts.each do |host|

    context 'libkv put operation' do
      let(:manifest) {
         <<-EOS
      file {'/var/simp/libkv':
        ensure => directory
      }

      # Calls libkv::put directly and via both a Puppet-language function
      # and a Ruby-language function
      # * Stores values of different types
      #   Ruby-language function, libkv_test::put_rwrapper, should go to the
      #   correct backend instance, 'file/class'.  libkv_test::put_rwrapper
      #   works properly because it is written in a way to access full scope.
      # * The put operations from the Puppet language function,
      #   libkv_test::put_pwrapper(), should go to the default backend instance,
      #   'file/default', instead of the correct backend instance.  This
      #   wrapper function cannot work properly because there is no way to
      #   inject the full scope into that function.
      class { 'libkv_test::put': }

      # These two defines call libkv::put directly and via the Ruby-language
      # function
      # * The 'define1' put operations should use the 'file/define_instance'
      #   backend instance.
      # * The 'define2' put operations should use the 'file/define_type'
      libkv_test::defines::put { 'define1': }
      libkv_test::defines::put { 'define2': }
        EOS
      }

      it 'should work with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      [
        '/var/simp/libkv/file/class/production/class/bool',
        '/var/simp/libkv/file/class/production/class/string',
        #'/var/simp/libkv/file/class/production/class/binary',
        '/var/simp/libkv/file/class/production/class/int',
        '/var/simp/libkv/file/class/production/class/float',
        '/var/simp/libkv/file/class/production/class/array_strings',
        '/var/simp/libkv/file/class/production/class/array_integers'
        '/var/simp/libkv/file/class/production/class/hash',

        '/var/simp/libkv/file/class/production/class/bool_with_meta',
        '/var/simp/libkv/file/class/production/class/string_with_meta',
        #'/var/simp/libkv/file/class/production/class/binary_with_meta',
        '/var/simp/libkv/file/class/production/class/int_with_meta',
        '/var/simp/libkv/file/class/production/class/float_with_meta',
        '/var/simp/libkv/file/class/production/class/array_strings_with_meta',
        '/var/simp/libkv/file/class/production/class/array_integers_with_meta',
        '/var/simp/libkv/file/class/production/class/hash_with_meta',

        '/var/simp/libkv/file/class/production/class/bool_from_rfunction',
        '/var/simp/libkv/file/default/production/class/bool_from_pfunction',

        '/var/simp/libkv/file/define_instance/production/define/define2/string',
        '/var/simp/libkv/file/define_instance/production/define/define2/string_from_rfunction',
        '/var/simp/libkv/file/define_type/production/define/define1/string',
        '/var/simp/libkv/file/define_type/production/define/define1/string_from_rfunction',
      ].each do |file|
        # validation of content will be done in gets test
        it 'should create #{file} key file' do
         
        end
      end
    end

    context 'libkv exists operation' do
      let(:manifest) {
        <<-EOS
        # class uses libkv::exists to verify the existence of keys in
        # the 'file/class' backend; fails compilation if the libkv::exists
        # result doesn't match what it expects
        class { 'libkv_test::exists': }
        EOS
      }

=begin
      it 'manifest should work with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end
=end
    end
=begin

    context 'libkv get operation' do
      let(:manifest) {
        <<-EOS
        # class uses libkv::get to retrieve values with/without metadata for
        # keys in the 'file/class' backend ; fails compilation if the retrieved
        # info does match what it expects
        class { 'libkv_test::get': }
        EOS
      }

    end

    context 'libkv list operation' do
      let(:manifest) {
        <<-EOS
        # class uses libkv::list to retrieve list of keys/values/metadata tuples for
        # keys in the 'file/class' backend ; fails compilation if the retrieved
        # info does match what it expects
        class { 'libkv_test::exists': }
        EOS
      }

    end

    context 'libkv delete operation' do
      let(:manifest) {
        <<-EOS
        # class uses libkv::delete to remove a subset of keys in the 'file/class'
        # backend
        class { 'libkv_test::delete': }
        EOS
      }

    end

    context 'libkv deletetree operation' do
      let(:manifest) {
        <<-EOS
        # class uses libkv::deletetree to remove the remaining keys in the 'file/class'
        # backend
        class { 'libkv_test::deletetree': }
        EOS
      }

    end

  end
=end
end
