class libkv_test::put(
  Boolean        $test_bool           = true,
  String         $test_string         = 'string1',
  Integer        $test_integer        = 123,
  Float          $test_float          = 4.567,
  Array          $test_array_strings  = ['string2', 'string3' ],
  Array[Integer] $test_array_integers = [ 8, 9, 10],
  Hash           $test_hash           = { 'key1' => 'string4', 'key2' => 11,
    'key3' => false, 'key4' => { 'nkey1' => 'string5', 'nkey2' => true, 'nkey3' => 12 } },
  Hash           $test_meta           = { 'some' => 'metadata' },
  Hash           $libkv_options       = { 'resource' => 'Class[Libkv_test::Put]' }

) {

  # Call libkv::put directly - will correctly pick backend
  $_empty_test_meta = {}
  libkv::put('from_class/boolean', $test_bool, $_empty_test_meta, $libkv_options)
  libkv::put('from_class/string', $test_string, $_empty_test_meta, $libkv_options)
  libkv::put('from_class/integer', $test_integer, $_empty_test_meta, $libkv_options)
  libkv::put('from_class/float', $test_float, $_empty_test_meta, $libkv_options)
  libkv::put('from_class/array_strings', $test_array_strings, $_empty_test_meta, $libkv_options)
  libkv::put('from_class/array_integers', $test_array_integers, $_empty_test_meta, $libkv_options)
  libkv::put('from_class/hash', $test_hash, $_empty_test_meta, $libkv_options)

  # Add keys with metadata
  libkv::put('from_class/boolean_with_meta', $test_bool, $test_meta, $libkv_options )
  libkv::put('from_class/string_with_meta', $test_string, $test_meta, $libkv_options)
  libkv::put('from_class/integer_with_meta', $test_integer, $test_meta, $libkv_options)
  libkv::put('from_class/float_with_meta', $test_float, $test_meta, $libkv_options)
  libkv::put('from_class/array_strings_with_meta', $test_array_strings, $test_meta, $libkv_options)
  libkv::put('from_class/array_integers_with_meta', $test_array_integers, $test_meta, $libkv_options)
  libkv::put('from_class/hash_with_meta', $test_hash, $test_meta, $libkv_options)

  libkv_test::put_pwrapper('from_class/boolean_from_pfunction', $test_bool, $libkv_options)

  # without the calling resource in the options, this key will be stored in the default backend
  $_empty_libkv_options = {}
  libkv_test::put_pwrapper('from_class/boolean_from_pfunction_no_resource', $test_bool, $_empty_libkv_options)
}
