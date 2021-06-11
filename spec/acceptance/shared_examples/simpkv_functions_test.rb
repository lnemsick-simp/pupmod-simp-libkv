# Execute and verify simpkv::functions
#
# - Uses a set of backend instances of the specified simpkv plugin type to
#   verify app_id-based backend selection. (See hieradata description block
#   below)
# - Uses the simpkv_test module to exercise the simpkv::* functions and to
#   verify their operation independent of the backend type used.
#   - The simpkv_test module exclusively uses simpkv functions for store/retrieve
#     operations.
#   - Use of simpkv functions provides a self-consistency check, but is
#     insufficient.
# - Uses backend-specific validator function to independently verify keys
#   and folders are present/absent in the backend.
#   - Necessary to ensure store/retrieve operations are going where we think
#     they are going!
#   - TODO Only a subset of data is checked at this time.
# - Sorry, this is a very long test file, because each step builds on previous
#   steps.
#   - Keys have to be added before they can be checked/retrieved/deleted.
#   - Validation of these additions and removals assumes a specific
#     order of backend operations.
#
# @param host Host object
#
# Assumed available context:
#   options = Test options hash
#   {
#     :backend_configs => {
#       # Plugin specific config for each backend;
#       # - Backends can be any mix of types
#       # - Each config must include 'type' attribute
#       :class_keys           => { },
#       :specific_define_keys => { },
#       :define_keys          => { },
#       :default              => { }
#     },
#     :validator => <Method object that can be called to independently validate
#                    backend state>
#   }
#
#   Validator method will return a Boolean and will be called with the following
#   arguments:
#   - path to check
#   - path type (:key, :folder)
#   - puppet environment: string for a Puppet environment key, nil for a global key
#   - check operation (:present, :absent)
#   - backend configuration hash
#   - Host object on which validation commands will be executed
#
shared_examples 'simpkv functions test' do |host|

  let(:backend_configs) {
    configs = Marshal.load(Marshal.dump(options[:backend_configs]))
    configs[:class_keys]['id'] = 'class_keys'
    configs[:specific_define_keys]['id'] = 'specific_define_keys'
    configs[:define_keys]['id'] = 'define_keys'
    configs[:default]['id'] = 'default'
    configs
  }

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
    'simpkv::backend::class_keys' => backend_configs[:class_keys],

    # Backend for keys stored via simpkv::put() with app_id='Simpkv::Defines::Put[define2]'
    # ==> keys stored in the 'define2' instance of the simpkv_test::defines::put define
    'simpkv::backend::specific_define_keys' => backend_configs[:specific_define_keys],

    # Backend for keys stored via simpkv::put() with app_id matching
    # 'Simpkv::Defines::Put'
    # ==> keys stored in any other instance of the simpkv_test::defines::put define
    'simpkv::backend::define_keys' => backend_configs[:define_keys],

    # Backend for keys stored via simpkv::put() without an app_id or an app_id
    # that doesn't match anything else
    'simpkv::backend::default' => backend_configs[:default],

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
    #   'default' backend instance.
    # * All the rest of the store operations will go to the 'class_keys'
    #   backend instance.
    class { 'simpkv_test::put': }

    # These two defines call simpkv::put directly and via the Puppet-language
    # function
    # * The 'define1' put operations should use the 'define_keys'
    #   backend instance.
    # * The 'define2' put operations should use the 'specific_define_keys'
    #   backend instance.
    simpkv_test::defines::put { 'define1': }
    simpkv_test::defines::put { 'define2': }
      EOS
    }

    it 'should work with no errors' do
      set_hieradata_on(host, hieradata)
      apply_manifest_on(host, manifest, :catch_failures => true)
    end

    # The validation of the existence and content of the keys we just stored
    # will be done in subsequent tests using simpkv::exists() and simpkv::get().
    # However, those tests are not plugin-specific and won't find issues in
    # which we think we are storing the keys using one type of plugin, but
    # instead are using another plugin (e.g., the default file plugin). So,
    # we need to independently validate the keys were actually stored in
    # the backend being tested. For simplicity, we are simply going to
    # test for the existence of folders and keys in the backend.
    {
      :class_keys           => {
        :global_folders     => [],
        :global_keys        => [],
        :production_folders => [
          'from_class'
        ],
        :production_keys    => [
          'from_class/boolean',
          'from_class/string',
          'from_class/integer',
          'from_class/float',
          'from_class/array_strings',
          'from_class/array_integers',
          'from_class/hash',
          'from_class/boolean_with_meta',
          'from_class/string_with_meta',
          'from_class/integer_with_meta',
          'from_class/float_with_meta',
          'from_class/array_strings_with_meta',
          'from_class/array_integers_with_meta',
          'from_class/hash_with_meta',
          'from_class/boolean_from_pfunction',
        ]
      },
      :specific_define_keys => {
        :global_folders     => [],
        :global_keys        => [],
        :production_folders => [
          'from_define',
          'from_define/define2'
        ],
        :production_keys    => [
          'from_define/define2/string',
          'from_define/define2/string_from_pfunction'
        ]
      },
      :define_keys          => {
        :global_folders     => [],
        :global_keys        => [],
        :production_folders => [
          'from_define',
          'from_define/define1'
        ],
        :production_keys    => [
          'from_define/define1/string',
          'from_define/define1/string_from_pfunction'
        ]
      },
      :default              => {
        :global_folders     => [],
        :global_keys        => [],
        :production_folders => [
          'from_class'
        ],
        :production_keys    => [
          'from_class/boolean_from_pfunction_no_app_id'
        ]
      }
    }.each do |backend, data|
      data[:global_folders].each do |folder|
        it "should create '#{folder}' global folder in #{backend} backend" do
          result = options[:validator].call(folder, :folder, nil, :present,
            backend_configs[backend], host)
          expect(result). to be true
        end
      end

      data[:global_keys].each do |key|
        it "should create '#{key}' global key in #{backend} backend" do
          result = options[:validator].call(key, :key, nil, :present,
            backend_configs[backend], host)
          expect(result). to be true
        end
      end

      data[:production_folders].each do |folder|
        it "should create '#{folder}' production env folder in #{backend} backend" do
          result = options[:validator].call(folder, :folder, 'production', :present,
            backend_configs[backend], host)
          expect(result). to be true
        end
      end

      data[:production_keys].each do |key|
        it "should create '#{key}' production env key in #{backend} backend" do
          result = options[:validator].call(key, :key, 'production', :present,
            backend_configs[backend], host)
          expect(result). to be true
        end
      end
    end
  end

  context 'simpkv exists operation' do
    let(:manifest) {
      <<-EOS
      # class uses simpkv::exists to verify
      # - The existence of all keys in the 'class_keys' and 'default' backends
      # - A key in the 'default' backend can't be retrieved using the app_id
      #   mapped to the 'class_keys' backend.
      #
      # Fails compilation if any simpkv::exists result doesn't match
      # expected
      class { 'simpkv_test::exists': }
      EOS
    }

    it 'manifest should work with no errors' do
      apply_manifest_on(host, manifest, :catch_failures => true)
    end
  end

  context 'simpkv get operation' do
    let(:manifest) {
      # TODO update simpkv_test::get to verify keys from all backends
      <<-EOS
      # class uses simpkv::get to retrieve values with/without metadata for
      # keys in the 'class_keys' backend; fails compilation if any retrieved
      # info does not match expected
      class { 'simpkv_test::get': }
      EOS
    }

    it 'manifest should work with no errors' do
      apply_manifest_on(host, manifest, :catch_failures => true)
    end

  end

  context 'simpkv list operation' do
    let(:manifest) {
      # TODO update simpkv_test::list to verify key lists from all backends
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
      # backend and the simpkv::exists to verify they are gone and that the
      # other keys are still present; fails compilation if any removed keys
      # still exist or any preserved keys have been removed
      class { 'simpkv_test::delete': }
      EOS
    }

    it 'manifest should work with no errors' do
      apply_manifest_on(host, manifest, :catch_failures => true)
    end

    # In the above test, we have already verified the keys we wanted to delete
    # have been removed using simpkv::exists(). However, we just want to be sure
    # using an independent, plugin-specific validator.
    [
      'from_class/boolean',
      'from_class/string',
      'from_class/integer',
      'from_class/float',
      'from_class/array_strings',
      'from_class/array_integers',
      'from_class/hash',
    ].each do |key|
      it "should remove '#{key}' production env key in 'class_keys' backend" do
        result = options[:validator].call(key, :key, 'production', :absent,
          backend_configs[:class_keys], host)
        expect(result). to be true
      end
    end
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

    it 'should remove specified folder' do
      result = options[:validator].call('from_class', :folder, 'production', :absent,
        backend_configs[:class_keys], host)
      expect(result). to be true
    end
  end

  context 'simpkv operations for binary data' do
    context 'prep' do
      it 'should have a clean start' do
        on(host, 'rm -rf /root/binary_data')
      end

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

