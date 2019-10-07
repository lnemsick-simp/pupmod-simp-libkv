# This class sets key/value parameters used in libkv_test manifests.
class libkv_test::params (
  String         $test_keydir             = 'from_class',
  String         $test_bool_key           = "${test_keydir}/boolean",
  String         $test_string_key         = "${test_keydir}/string",
  String         $test_integer_key        = "${test_keydir}/integer",
  String         $test_float_key          = "${test_keydir}/float",
  String         $test_array_strings_key  = "${test_keydir}/array_strings",
  String         $test_array_integers_key = "${test_keydir}/array_integers",
  String         $test_hash_key           = "${test_keydir}/hash",

  Boolean        $test_bool               = true,
  String         $test_string             = 'string1',
  Integer        $test_integer            = 123,
  Float          $test_float              = 4.567,
  Array          $test_array_strings      = ['string2', 'string3' ],
  Array[Integer] $test_array_integers     = [ 8, 9, 10],
  Hash           $test_hash               = { 'key1' => 'string4', 'key2' => 11,
    'key3' => false, 'key4' => { 'nkey1' => 'string5', 'nkey2' => true, 'nkey3' => 12 } },

  Hash           $key_value_pairs         = { $test_bool_key           => $test_bool,
                                              $test_string_key         => $test_string,
                                              $test_integer_key        => $test_integer,
                                              $test_float_key          => $test_float,
                                              $test_array_strings_key  => $test_array_strings,
                                              $test_array_integers_key => $test_array_integers,
                                              $test_hash_key           => $test_hash },

  Hash           $test_meta               = { 'some' => 'metadata' },
  Hash           $libkv_options           = { 'app_id' => 'libkv_test_class' }
) { }
