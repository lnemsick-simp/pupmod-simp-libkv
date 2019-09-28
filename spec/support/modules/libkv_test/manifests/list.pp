class libkv_test::list(
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

  $_expected = {
    'class/bool'                     => { 'value' => $test_bool },
    'class/string'                   => { 'value' => $test_string },
##    'class/binary'                 => { 'value' => $test_binary },
    'class/int'                      => { 'value' => $test_integer },
    'class/float'                    => { 'value' => $test_float },
    'class/array_strings'            => { 'value' => $test_array_strings },
    'class/array_integers'           => { 'value' => $test_array_integers },
    'class/hash'                     => { 'value' => $test_hash },

    'class/bool_with_meta'           => { 'value' => $test_bool, 'metadata' => $test_meta },
    'class/string_with_meta'         => { 'value' => $test_string, 'metadata' => $test_meta },
##    'class/binary_with_meta'       => $test_binary, { 'value' => $test_binary, 'metadata' => $test_meta },
    'class/int_with_meta'            => { 'value' => $test_integer, 'metadata' => $test_meta },
    'class/float_with_meta'          => { 'value' => $test_float, 'metadata' => $test_meta },
    'class/array_strings_with_meta'  => { 'value' => $test_array_strings, 'metadata' => $test_meta },
    'class/array_integers_with_meta' => { 'value' => $test_array_integers, 'metadata' => $test_meta },
    'class/hash_with_meta'           => { 'value' => $test_hash, 'metadata' => $test_meta },

    'class/bool_from_rfunction'      => { 'value' => $test_bool }
  }

  libkv_test::assert_equal(libkv::list('class'), $_expected, "libkv::list('class')")
}
