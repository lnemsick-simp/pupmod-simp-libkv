# Execute and verify simpkv::functions
#
# - Uses a set of backend instances of the specified simpkv plugin type to
#   verify app_id-based backend selection. (See hieradata description block
#   below)
# - Uses the simpkv_test module to use the simpkv::* functions and to
#   verify their operation independent of the backend type used.
#
# @param host Host object
#
# Assumed available context:
#   options = Test options hash
#   {
#     :type            => '<plugin type>',
#     :backend_configs => {
#       # Plugin specific config for each backend;
#       # Will be merged with base config.
#       :class_keys           => { },
#       :specific_define_keys => { },
#       :define_keys          => { },
#       :default              => { }
#     }
#   }
shared_examples 'simpkv functions test' do |host|

  let(:hieradata) {{

    #############################################################################
    # The selection of the backend to use to access a key/value entry is based
    # the optional, user-defined app_id that is specified in each simpkv::*
    # function call.
    # - When app_id is present, simpkv selects the backend that most-specifically
    #   matches the app_id, or, if no match is found, the required 'default'
    #   backend.
    # - When app_id is absent, simpkv selects the 'default' backend.
    #
    # In these tests, the manifests specify app_ids based on the type of
    # resource in which the entry was created. (The app_ids look like catalog
    # resource strings). This is totally **artificial** naming and grouping!
    # However, it demonstrates backend selection and exercises the simpkv::*
    # functions in Classes, Defines, and Puppet-language functions.
    #############################################################################

    # Backend definitions which will be mapped to app_id in simpkv::options

    # Backend for keys stored via simpkv::put() with app_id='Class[Simpkv::Put]'
    # ==> most of the keys stored in the simpkv_test::put class
    'simpkv::backend::class_keys' => {
      'type'      => options[:type],
      'id'        => 'class_keys'
    }.merge(options[:backend_configs][:class_keys]),

    # Backend for keys stored via simpkv::put() with app_id='Simpkv::Defines::Put[define2]'
    # ==> keys stored in the 'define2' instance of the simpkv_test::defines::put define
    'simpkv::backend::specific_define_keys' => {
      'type'      => options[:type],
      'id'        => 'specific_define_keys'
    }.merge(options[:backend_configs][:specific_define_keys]),


    # Backend for keys stored via simpkv::put() with app_id matching
    # 'Simpkv::Defines::Put'
    # ==> keys stored in any other instance of the simpkv_test::defines::put define
    'simpkv::backend::define_keys' => {
      'type'      => options[:type],
      'id'        => 'define_keys'
    }.merge(options[:backend_configs][:define_keys]),

    # Backend for keys stored via simpkv::put() without an app_id or an app_id
    # that doesn't match anything else
    'simpkv::backend::default' => {
      'type'      => options[:type],
      'id'        => 'default'
    }.merge(options[:backend_configs][:default]),

   'simpkv::options' => {
      'environment' => '%{server_facts.environment}',
      'softfail'    => false,
      'backends' => {
        'Class[Simpkv_test::Put]'            => "%{alias('simpkv::backend::class_keys')}",
        'Simpkv_test::Defines::Put[define2]' => "%{alias('simpkv::backend::specific_define_keys')}",
        'Simpkv_test::Defines::Put'          => "%{alias('simpkv::backend::define_keys')}",
        'default'                            => "%{alias('simpkv::backend::default')}",
      }
    }
  }}

  context 'simpkv put operation' do
    let(:manifest) {
       <<-EOS
    # Calls simpkv::put directly and via a Puppet-language function
    # * Stores values of different types.  Binary content is handled
    #   via a separate test.
    # * One of the calls to the Puppet-language function will go to the
    #   default backend.
    class { 'simpkv_test::put': }

    # These two defines call simpkv::put directly and via the Puppet-language
    # function
    # * The 'define1' put operations should use the 'specific_define_keys'
    #   backend instance.
    # * The 'define2' put operations should use the 'define_keys'
    #   backend instance.
    simpkv_test::defines::put { 'define1': }
    simpkv_test::defines::put { 'define2': }
      EOS
    }

    it 'should work with no errors' do
      set_hieradata_on(host, hieradata)
      apply_manifest_on(host, manifest, :catch_failures => true)
    end

=begin
# FIXME need insert point to call validation function
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
=end
  end

  context 'simpkv exists operation' do
    let(:manifest) {
      <<-EOS
      # class uses simpkv::exists to verify the existence of keys in
      # the 'class_keys' backend; fails compilation if any simpkv::exists
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
      # keys in the 'class_keys' backend; fails compilation if any
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
      # for keys in the 'class_keys' backend; fails compilation if the
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
      # class uses simpkv::delete to remove a subset of keys in the 'class_keys'
      # backend and the simpkv::exists to verify they are gone but the other keys
      # are still present; fails compilation if any removed keys still exist or
      # any preserved keys have been removed
      class { 'simpkv_test::delete': }
      EOS
    }

    it 'manifest should work with no errors' do
      apply_manifest_on(host, manifest, :catch_failures => true)
    end

=begin
# FIXME insertion point for validation of delete operation
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
=end
  end

  context 'simpkv deletetree operation' do
    let(:manifest) {
      <<-EOS
      # class uses simpkv::deletetree to remove the remaining keys in the 'class_keys'
      # backend and the simpkv::exists to verify all keys are gone; fails compilation
      # if any keys remain
      class { 'simpkv_test::deletetree': }
      EOS
    }

    it 'manifest should work with no errors' do
      apply_manifest_on(host, manifest, :catch_failures => true)
    end

=begin
# FIXME insertion point for validation of deletetree operation
    it 'should remove specified folder' do
      expect( file_exists_on(host, '/var/simp/simpkv/file/class/production/from_class/') ).to be false
    end
=end
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

=begin
# FIXME insertion point for validation of binary put operation
      [
        '/var/simp/simpkv/file/default/production/from_class/binary',
        '/var/simp/simpkv/file/default/production/from_class/binary_with_meta'
      ].each do |file|
        it "should create #{file}" do
          expect( file_exists_on(host, file) ).to be true
        end
      end
=end
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

