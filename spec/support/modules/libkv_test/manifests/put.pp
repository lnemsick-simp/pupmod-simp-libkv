class libkv_test::put(
  Boolean        $test_bool           = true,
  String         $test_string         = 'string1',
  Integer        $test_integer        = 123,
  Float          $test_float          = 4.567,
  Array          $test_array_strings  = ['string2', 'string3' ],
  Array[Integer] $test_array_integers = [ 8, 9, 10],
  Hash           $test_hash           = { 'key1' => 'string4', 'key2' => 11,
    'key3' => false, 'key4' => { 'nkey1' => 'string5', 'nkey2' => true, 'nkey3' => 12 } },
  Hash           $test_meta           = { 'some' => 'metadata' }

) {

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  # Call libkv::put directly - will correctly pick backend
  libkv::put('from_class/boolean', $test_bool)
  libkv::put('from_class/string', $test_string)
  libkv::put('from_class/integer', $test_integer)
  libkv::put('from_class/float', $test_float)
  libkv::put('from_class/array_strings', $test_array_strings)
  libkv::put('from_class/array_integers', $test_array_integers)
  libkv::put('from_class/hash', $test_hash)

  # Add keys with metadata
  libkv::put('from_class/boolean_with_meta', $test_bool, $test_meta )
  libkv::put('from_class/string_with_meta', $test_string, $test_meta)
  libkv::put('from_class/integer_with_meta', $test_integer, $test_meta)
  libkv::put('from_class/float_with_meta', $test_float, $test_meta)
  libkv::put('from_class/array_strings_with_meta', $test_array_strings, $test_meta)
  libkv::put('from_class/array_integers_with_meta', $test_array_integers, $test_meta)
  libkv::put('from_class/hash_with_meta', $test_hash, $test_meta)

  # Call libkv::put via a Puppet Ruby function - will correctly pick backend
  libkv_test::put_rwrapper('from_class/boolean_from_rfunction', $test_bool)

  # Call libkv::put via a Puppet language function - will use default backend
  # instead of correct backend
  libkv_test::put_pwrapper('from_class/boolean_from_pfunction', $test_bool)
}
