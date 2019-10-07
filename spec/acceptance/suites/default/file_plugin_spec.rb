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
      'libkv_test_class'                  => "%{alias('libkv::backend::file_class')}",
      'Libkv_test::Defines::Put[define2]' => "%{alias('libkv::backend::file_define_instance')}",
      'Libkv_test::Defines::Put'          => "%{alias('libkv::backend::file_define_type')}",
      'default'                           => "%{alias('libkv::backend::file_default')}",
      }

    }

  }}

  hosts.each do |host|
    context 'with libkv configuration via libkv::options' do

      context 'libkv put operation' do
        let(:manifest) {
           <<-EOS
        file {'/var/simp/libkv':
          ensure => directory
        }

        # Calls libkv::put directly and via a Puppet-language function
        # * Stores values of different types.  Binary content is handled
        #   via a separate test.
        # * One of the calls to the Puppet-language function will go to the
        #   default backend
        class { 'libkv_test::put': }

        # These two defines call libkv::put directly and via the Puppet-language
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
          '/var/simp/libkv/file/class/production/from_class/boolean',
          '/var/simp/libkv/file/class/production/from_class/string',
          '/var/simp/libkv/file/class/production/from_class/integer',
          '/var/simp/libkv/file/class/production/from_class/float',
          '/var/simp/libkv/file/class/production/from_class/array_strings',
          '/var/simp/libkv/file/class/production/from_class/array_integers',
          '/var/simp/libkv/file/class/production/from_class/hash',

          '/var/simp/libkv/file/class/production/from_class/boolean_with_meta',
          '/var/simp/libkv/file/class/production/from_class/string_with_meta',
          '/var/simp/libkv/file/class/production/from_class/integer_with_meta',
          '/var/simp/libkv/file/class/production/from_class/float_with_meta',
          '/var/simp/libkv/file/class/production/from_class/array_strings_with_meta',
          '/var/simp/libkv/file/class/production/from_class/array_integers_with_meta',
          '/var/simp/libkv/file/class/production/from_class/hash_with_meta',

          '/var/simp/libkv/file/class/production/from_class/boolean_from_pfunction',
          '/var/simp/libkv/file/default/production/from_class/boolean_from_pfunction_no_app_id',

          '/var/simp/libkv/file/define_instance/production/from_define/define2/string',
          '/var/simp/libkv/file/define_instance/production/from_define/define2/string_from_pfunction',
          '/var/simp/libkv/file/define_type/production/from_define/define1/string',
          '/var/simp/libkv/file/define_type/production/from_define/define1/string_from_pfunction'
        ].each do |file|
          # validation of content will be done in 'get' test
          it "should create #{file}" do
            expect( file_exists_on(host, file) ).to be true
          end
        end
      end

      context 'libkv exists operation' do
        let(:manifest) {
          <<-EOS
          # class uses libkv::exists to verify the existence of keys in
          # the 'file/class' backend; fails compilation if any libkv::exists
          # result doesn't match expected
          class { 'libkv_test::exists': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end
      end

      context 'libkv get operation' do
        let(:manifest) {
          <<-EOS
          # class uses libkv::get to retrieve values with/without metadata for
          # keys in the 'file/class' backend; fails compilation if any
          # retrieved info does match expected
          class { 'libkv_test::get': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

      end

      context 'libkv list operation' do
        let(:manifest) {
          <<-EOS
          # class uses libkv::list to retrieve list of keys/values/metadata tuples
          # for keys in the 'file/class' backend; fails compilation if the
          # retrieved info does match expected
          class { 'libkv_test::list': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

      end

      context 'libkv delete operation' do
        let(:manifest) {
          <<-EOS
          # class uses libkv::delete to remove a subset of keys in the 'file/class'
          # backend and the libkv::exists to verify they are gone but the other keys
          # are still present; fails compilation if any removed keys still exist or
          # any preserved keys have been removed
          class { 'libkv_test::delete': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        [
          '/var/simp/libkv/file/class/production/from_class/boolean',
          '/var/simp/libkv/file/class/production/from_class/string',
          '/var/simp/libkv/file/class/production/from_class/integer',
          '/var/simp/libkv/file/class/production/from_class/float',
          '/var/simp/libkv/file/class/production/from_class/array_strings',
          '/var/simp/libkv/file/class/production/from_class/array_integers',
          '/var/simp/libkv/file/class/production/from_class/hash',
        ].each do |file|
          it "should remove #{file}" do
            expect( file_exists_on(host, file) ).to be false
          end
        end


      end

      context 'libkv deletetree operation' do
        let(:manifest) {
          <<-EOS
          # class uses libkv::deletetree to remove the remaining keys in the 'file/class'
          # backend and the libkv::exists to verify all keys are gone; fails compilation
          # if any keys remain
          class { 'libkv_test::deletetree': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it 'should remove specified folder' do
          expect( file_exists_on(host, '/var/simp/libkv/file/class/production/from_class/') ).to be false
        end
      end

      context 'libkv operations for binary data' do
        context 'prep' do
          it 'should create a binary file for test' do
            on(host, 'mkdir /root/binary_data')
            on(host, 'dd count=1 if=/dev/urandom of=/root/binary_data/input_data')
          end
        end

        context 'libkv put operation for Binary type' do
          let(:manifest) {
            <<-EOS
            # class uses libkv::put to store binary data from binary_file() in
            # a Binary type
            class { 'libkv_test::binary_put': }
            EOS
          }

          it 'manifest should work with no errors' do
            apply_manifest_on(host, manifest, :catch_failures => true)
          end

          [
            '/var/simp/libkv/file/default/production/from_class/binary',
            '/var/simp/libkv/file/default/production/from_class/binary_with_meta'
          ].each do |file|
            it "should create #{file}" do
              expect( file_exists_on(host, file) ).to be true
            end
          end
        end

        context 'libkv get operation for Binary type' do
          let(:manifest) {
            <<-EOS
            # class uses libkv::get to retrieve binary data for Binary type variables
            # and to persist new files with binary content; fails compilation if any
            # retrieved info does match expected
            class { 'libkv_test::binary_get': }
            EOS
          }

          it 'manifest should work with no errors' do
            apply_manifest_on(host, manifest, :catch_failures => true)
          end

          {
            'retrieved_data1' => 'retrieved from key without metadata',
            'retrieved_data2' => 'retrieved from key with metadata'
          }.each do |output_file,summary|
            it "should create binary file #{summary} that matches input binary file" do
              on(host, "diff /root/binary_data/input_data /root/binary_data/#{output_file}")
            end
          end
        end
      end
    end

    context 'without libkv configuration' do
      let(:manifest) {
        <<-EOS
          libkv_test::defines::put { 'define1': }
          libkv_test::defines::put { 'define2': }
        EOS
      }

      it 'should work with no errors' do
        # clear out hieradata that contained libkv::options
        set_hieradata_on(host, {})
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should store keys in auto-default backend' do
        [
          '/var/simp/libkv/file/auto_default/production/from_define/define2/string',
          '/var/simp/libkv/file/auto_default/production/from_define/define2/string_from_pfunction',
          '/var/simp/libkv/file/auto_default/production/from_define/define1/string',
          '/var/simp/libkv/file/auto_default/production/from_define/define1/string_from_pfunction'
        ].each do |file|
          expect( file_exists_on(host, file) ).to be true
        end
      end
    end
  end
end
