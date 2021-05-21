=begin
require 'spec_helper_acceptance'

test_name 'simpkv file plugin'

describe 'simpkv file plugin' do

  let(:hieradata) {{

    'simpkv::backend::file_class' => {
      'type'      => 'file',
      'id'        => 'class',
      'root_path' => '/var/simp/simpkv/file/class'
    },

    'simpkv::backend::file_define_instance' => {
      'type'      => 'file',
      'id'        => 'define_instance',
      'root_path' => '/var/simp/simpkv/file/define_instance'
    },

    'simpkv::backend::file_define_type' => {
      'type'      => 'file',
      'id'        => 'define_type',
      'root_path' => '/var/simp/simpkv/file/define_type'
    },

    'simpkv::backend::file_default' => {
      'type'      => 'file',
      'id'        => 'default',
      'root_path' => '/var/simp/simpkv/file/default'
    },

   'simpkv::options' => {
      'environment' => '%{server_facts.environment}',
      'softfail'    => false,
      'backends' => {
      'simpkv_test_class'                  => "%{alias('simpkv::backend::file_class')}",
      'Simpkv_test::Defines::Put[define2]' => "%{alias('simpkv::backend::file_define_instance')}",
      'Simpkv_test::Defines::Put'          => "%{alias('simpkv::backend::file_define_type')}",
      'default'                           => "%{alias('simpkv::backend::file_default')}",
      }

    }

  }}

  hosts.each do |host|
    context 'with simpkv configuration via simpkv::options' do

      context 'simpkv put operation' do
        let(:manifest) {
           <<-EOS
        file {'/var/simp/simpkv':
          ensure => directory
        }

        # Calls simpkv::put directly and via a Puppet-language function
        # * Stores values of different types.  Binary content is handled
        #   via a separate test.
        # * One of the calls to the Puppet-language function will go to the
        #   default backend
        class { 'simpkv_test::put': }

        # These two defines call simpkv::put directly and via the Puppet-language
        # function
        # * The 'define1' put operations should use the 'file/define_instance'
        #   backend instance.
        # * The 'define2' put operations should use the 'file/define_type'
        simpkv_test::defines::put { 'define1': }
        simpkv_test::defines::put { 'define2': }
          EOS
        }

        it 'should work with no errors' do
          set_hieradata_on(host, hieradata)
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        [
          '/var/simp/simpkv/file/class/production/from_class/boolean',
          '/var/simp/simpkv/file/class/production/from_class/string',
          '/var/simp/simpkv/file/class/production/from_class/integer',
          '/var/simp/simpkv/file/class/production/from_class/float',
          '/var/simp/simpkv/file/class/production/from_class/array_strings',
          '/var/simp/simpkv/file/class/production/from_class/array_integers',
          '/var/simp/simpkv/file/class/production/from_class/hash',

          '/var/simp/simpkv/file/class/production/from_class/boolean_with_meta',
          '/var/simp/simpkv/file/class/production/from_class/string_with_meta',
          '/var/simp/simpkv/file/class/production/from_class/integer_with_meta',
          '/var/simp/simpkv/file/class/production/from_class/float_with_meta',
          '/var/simp/simpkv/file/class/production/from_class/array_strings_with_meta',
          '/var/simp/simpkv/file/class/production/from_class/array_integers_with_meta',
          '/var/simp/simpkv/file/class/production/from_class/hash_with_meta',

          '/var/simp/simpkv/file/class/production/from_class/boolean_from_pfunction',
          '/var/simp/simpkv/file/default/production/from_class/boolean_from_pfunction_no_app_id',

          '/var/simp/simpkv/file/define_instance/production/from_define/define2/string',
          '/var/simp/simpkv/file/define_instance/production/from_define/define2/string_from_pfunction',
          '/var/simp/simpkv/file/define_type/production/from_define/define1/string',
          '/var/simp/simpkv/file/define_type/production/from_define/define1/string_from_pfunction'
        ].each do |file|
          # validation of content will be done in 'get' test
          it "should create #{file}" do
            expect( file_exists_on(host, file) ).to be true
          end
        end
      end

      context 'simpkv exists operation' do
        let(:manifest) {
          <<-EOS
          # class uses simpkv::exists to verify the existence of keys in
          # the 'file/class' backend; fails compilation if any simpkv::exists
          # result doesn't match expected
          class { 'simpkv_test::exists': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end
      end

      context 'simpkv get operation' do
        let(:manifest) {
          <<-EOS
          # class uses simpkv::get to retrieve values with/without metadata for
          # keys in the 'file/class' backend; fails compilation if any
          # retrieved info does match expected
          class { 'simpkv_test::get': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

      end

      context 'simpkv list operation' do
        let(:manifest) {
          <<-EOS
          # class uses simpkv::list to retrieve list of keys/values/metadata tuples
          # for keys in the 'file/class' backend; fails compilation if the
          # retrieved info does match expected
          class { 'simpkv_test::list': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

      end

      context 'simpkv delete operation' do
        let(:manifest) {
          <<-EOS
          # class uses simpkv::delete to remove a subset of keys in the 'file/class'
          # backend and the simpkv::exists to verify they are gone but the other keys
          # are still present; fails compilation if any removed keys still exist or
          # any preserved keys have been removed
          class { 'simpkv_test::delete': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        [
          '/var/simp/simpkv/file/class/production/from_class/boolean',
          '/var/simp/simpkv/file/class/production/from_class/string',
          '/var/simp/simpkv/file/class/production/from_class/integer',
          '/var/simp/simpkv/file/class/production/from_class/float',
          '/var/simp/simpkv/file/class/production/from_class/array_strings',
          '/var/simp/simpkv/file/class/production/from_class/array_integers',
          '/var/simp/simpkv/file/class/production/from_class/hash',
        ].each do |file|
          it "should remove #{file}" do
            expect( file_exists_on(host, file) ).to be false
          end
        end


      end

      context 'simpkv deletetree operation' do
        let(:manifest) {
          <<-EOS
          # class uses simpkv::deletetree to remove the remaining keys in the 'file/class'
          # backend and the simpkv::exists to verify all keys are gone; fails compilation
          # if any keys remain
          class { 'simpkv_test::deletetree': }
          EOS
        }

        it 'manifest should work with no errors' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it 'should remove specified folder' do
          expect( file_exists_on(host, '/var/simp/simpkv/file/class/production/from_class/') ).to be false
        end
      end

      context 'simpkv operations for binary data' do
        context 'prep' do
          it 'should create a binary file for test' do
            on(host, 'mkdir /root/binary_data')
            on(host, 'dd count=1 if=/dev/urandom of=/root/binary_data/input_data')
          end
        end

        context 'simpkv put operation for Binary type' do
          let(:manifest) {
            <<-EOS
            # class uses simpkv::put to store binary data from binary_file() in
            # a Binary type
            class { 'simpkv_test::binary_put': }
            EOS
          }

          it 'manifest should work with no errors' do
            apply_manifest_on(host, manifest, :catch_failures => true)
          end

          [
            '/var/simp/simpkv/file/default/production/from_class/binary',
            '/var/simp/simpkv/file/default/production/from_class/binary_with_meta'
          ].each do |file|
            it "should create #{file}" do
              expect( file_exists_on(host, file) ).to be true
            end
          end
        end

        context 'simpkv get operation for Binary type' do
          let(:manifest) {
            <<-EOS
            # class uses simpkv::get to retrieve binary data for Binary type variables
            # and to persist new files with binary content; fails compilation if any
            # retrieved info does match expected
            class { 'simpkv_test::binary_get': }
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

    context 'without simpkv configuration' do
      let(:manifest) {
        <<-EOS
          simpkv_test::defines::put { 'define1': }
          simpkv_test::defines::put { 'define2': }
        EOS
      }

      it 'should work with no errors' do
        # clear out hieradata that contained simpkv::options
        set_hieradata_on(host, {})
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should store keys in auto-default backend' do
        [
          '/var/simp/simpkv/file/auto_default/production/from_define/define2/string',
          '/var/simp/simpkv/file/auto_default/production/from_define/define2/string_from_pfunction',
          '/var/simp/simpkv/file/auto_default/production/from_define/define1/string',
          '/var/simp/simpkv/file/auto_default/production/from_define/define1/string_from_pfunction'
        ].each do |file|
          expect( file_exists_on(host, file) ).to be true
        end
      end
    end
  end
end
=end
