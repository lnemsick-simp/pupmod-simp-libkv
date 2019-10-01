class libkv_test::list(
  Boolean        $test_bool           = true,
  String         $test_string         = 'string1',
  Integer        $test_integer        = 123,
  Float          $test_float          = 4.567,
  Array          $test_array_strings  = ['string2', 'string3' ],
  Array[Integer] $test_array_integers = [ 8, 9, 10],
  Hash           $test_hash           = { 'key1' => 'string4', 'key2' => 11,
    'key3' => false, 'key4' => { 'nkey1' => 'string5', 'nkey2' => true, 'nkey3' => 12 } },
  Hash           $test_meta           = { 'some' => 'metadata' },
  Hash           $libkv_options       = { 'resource' => 'Class[Libkv_test::List]' }

) {

  $_expected = {
    'from_class/boolean'                  => { 'value' => $test_bool },
    'from_class/string'                   => { 'value' => $test_string },
    'from_class/integer'                  => { 'value' => $test_integer },
    'from_class/float'                    => { 'value' => $test_float },
    'from_class/array_strings'            => { 'value' => $test_array_strings },
    'from_class/array_integers'           => { 'value' => $test_array_integers },
    'from_class/hash'                     => { 'value' => $test_hash },

    'from_class/boolean_with_meta'        => { 'value' => $test_bool, 'metadata' => $test_meta },
    'from_class/string_with_meta'         => { 'value' => $test_string, 'metadata' => $test_meta },
    'from_class/integer_with_meta'        => { 'value' => $test_integer, 'metadata' => $test_meta },
    'from_class/float_with_meta'          => { 'value' => $test_float, 'metadata' => $test_meta },
    'from_class/array_strings_with_meta'  => { 'value' => $test_array_strings, 'metadata' => $test_meta },
    'from_class/array_integers_with_meta' => { 'value' => $test_array_integers, 'metadata' => $test_meta },
    'from_class/hash_with_meta'           => { 'value' => $test_hash, 'metadata' => $test_meta },

    'from_class/boolean_from_pfunction'   => { 'value' => $test_bool }
  }

  libkv_test::assert_equal(libkv::list('from_class', $libkv_options), $_expected, "libkv::list('from_class')")
}
