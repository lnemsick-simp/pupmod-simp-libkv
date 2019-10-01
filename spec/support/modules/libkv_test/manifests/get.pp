class libkv_test::get(
  Boolean        $test_bool           = true,
  String         $test_string         = 'string1',
  Integer        $test_integer        = 123,
  Float          $test_float          = 4.567,
  Array          $test_array_strings  = ['string2', 'string3' ],
  Array[Integer] $test_array_integers = [ 8, 9, 10],
  Hash           $test_hash           = { 'key1' => 'string4', 'key2' => 11,
    'key3' => false, 'key4' => { 'nkey1' => 'string5', 'nkey2' => true, 'nkey3' => 12 } },
  Hash           $test_meta           = { 'some' => 'metadata' },
  Hash           $libkv_options       = { 'resource' => 'Class[Libkv_test::Get]' }

) {

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  libkv_test::assert_equal(libkv::get('from_class/boolean', $libkv_options), { 'value' => $test_bool }, "libkv::get('from_class/boolean')")
  libkv_test::assert_equal(libkv::get('from_class/string', $libkv_options), { 'value' => $test_string }, "libkv::get('from_class/string')")
  libkv_test::assert_equal(libkv::get('from_class/integer', $libkv_options), { 'value' => $test_integer }, "libkv::get('from_class/integer')")
  libkv_test::assert_equal(libkv::get('from_class/float', $libkv_options), { 'value' => $test_float }, "libkv::get('from_class/float')")
  libkv_test::assert_equal(libkv::get('from_class/array_strings', $libkv_options), { 'value' => $test_array_strings }, "libkv::get('from_class/array_strings')")
  libkv_test::assert_equal(libkv::get('from_class/array_integers', $libkv_options), { 'value' => $test_array_integers }, "libkv::get('from_class/array_integers')")
  libkv_test::assert_equal(libkv::get('from_class/hash', $libkv_options), { 'value' => $test_hash }, "libkv::get('from_class/hash')")

  libkv_test::assert_equal(libkv::get('from_class/boolean_with_meta', $libkv_options), { 'value' => $test_bool, 'metadata' => $test_meta }, "libkv::get('from_class/boolean_with_meta')")
  libkv_test::assert_equal(libkv::get('from_class/string_with_meta', $libkv_options), { 'value' => $test_string, 'metadata' => $test_meta }, "libkv::get('from_class/string_with_meta')")
  libkv_test::assert_equal(libkv::get('from_class/integer_with_meta', $libkv_options), { 'value' => $test_integer, 'metadata' => $test_meta }, "libkv::get('from_class/integer_with_meta')")
  libkv_test::assert_equal(libkv::get('from_class/float_with_meta', $libkv_options), { 'value' => $test_float, 'metadata' => $test_meta }, "libkv::get('from_class/float_with_meta')")
  libkv_test::assert_equal(libkv::get('from_class/array_strings_with_meta', $libkv_options), { 'value' => $test_array_strings, 'metadata' => $test_meta }, "libkv::get('from_class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::get('from_class/array_integers_with_meta', $libkv_options), { 'value' => $test_array_integers, 'metadata' => $test_meta }, "libkv::get('from_class/array_integet_with_meta')")
  libkv_test::assert_equal(libkv::get('from_class/hash_with_meta', $libkv_options), { 'value' => $test_hash, 'metadata' => $test_meta }, "libkv::get('from_class/hash_with_meta')")

  libkv_test::assert_equal(libkv::get('from_class/boolean_from_pfunction', $libkv_options), { 'value' => $test_bool }, "libkv::get('from_class/boolean_from_pfunction')")
}
