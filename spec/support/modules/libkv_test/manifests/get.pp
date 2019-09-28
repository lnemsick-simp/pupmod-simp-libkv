class libkv_test::get(
  Boolean        $test_bool           = true,
  String         $test_string         = 'string1',
# Binary         $test_binary         = binary_file(),
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

  libkv_test::assert_equal(libkv::get('class/bool'), { 'value' => $test_bool }, "libkv::get('class/bool')")
  libkv_test::assert_equal(libkv::get('class/string'), { 'value' => $test_string }, "libkv::get('class/string')")
##  libkv_test::assert_equal(libkv::get('class/binary'), { 'value' => $test_binary }, "libkv::get('class/binary')")
  libkv_test::assert_equal(libkv::get('class/int'), { 'value' => $test_integer }, "libkv::get('class/int')")
  libkv_test::assert_equal(libkv::get('class/float'), { 'value' => $test_float }, "libkv::get('class/float')")
  libkv_test::assert_equal(libkv::get('class/array_strings'), { 'value' => $test_array_strings }, "libkv::get('class/array_strings')")
  libkv_test::assert_equal(libkv::get('class/array_integers'), { 'value' => $test_array_integers }, "libkv::get('class/array_integers')")
  libkv_test::assert_equal(libkv::get('class/hash'), { 'value' => $test_hash }, "libkv::get('class/hash')")

  libkv_test::assert_equal(libkv::get('class/bool_with_meta'), { 'value' => $test_bool, 'metadata' => $test_meta }, "libkv::get('class/bool_with_meta')")
  libkv_test::assert_equal(libkv::get('class/string_with_meta'), { 'value' => $test_string, 'metadata' => $test_meta }, "libkv::get('class/string_with_meta')")
##  libkv_test:;assert_equal(libkv::get('class/binary_with_meta', $test_binary, { 'value' => $test_binary, 'metadata' => $test_meta }, "libkv::get('class/binary_with_meta')")
  libkv_test::assert_equal(libkv::get('class/int_with_meta'), { 'value' => $test_integer, 'metadata' => $test_meta }, "libkv::get('class/int_with_meta')")
  libkv_test::assert_equal(libkv::get('class/float_with_meta'), { 'value' => $test_float, 'metadata' => $test_meta }, "libkv::get('class/float_with_meta')")
  libkv_test::assert_equal(libkv::get('class/array_strings_with_meta'), { 'value' => $test_array_strings, 'metadata' => $test_meta }, "libkv::get('class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::get('class/array_integers_with_meta'), { 'value' => $test_array_integers, 'metadata' => $test_meta }, "libkv::get('class/array_integet_with_meta')")
  libkv_test::assert_equal(libkv::get('class/hash_with_meta'), { 'value' => $test_hash, 'metadata' => $test_meta }, "libkv::get('class/hash_with_meta')")

  libkv_test::assert_equal(libkv::get('class/bool_from_rfunction'), { 'value' => $test_bool }, "libkv::get('class/bool_from_rfunction')")
}
