define libkv_test::defines::put(
  Boolean        $test_bool           = true,
  String         $test_string         = 'dstring1',
# Binary         $test_binary         = binary_file(),
  Integer        $test_integer        = 123,
  Float          $test_float          = 4.567,
  Array          $test_array_strings  = ['dstring2', 'dstring3' ],
  Array[Integer] $test_array_integers = [ 8, 9, 10],
  Hash           $test_hash           = { 'key1' => 'dstring4', 'key2' => 11,
    'key3' => false, 'key4' => { 'nkey1' => 'dstring5', 'nkey2' => true, 'nkey3' => 12 } },
  Hash           $test_meta           = { 'some' => 'dmetadata' }

) {

  libkv::put("define/${name}/bool", $test_bool)
  libkv::put("define/${name}/string", $test_string)
#  libkv::put("define/${name}/binary", $test_binary)
  libkv::put("define/${name}/int", $test_integer)
  libkv::put("define/${name}/float", $test_float)
  libkv::put("define/${name}/array_strings", $test_array_strings)
  libkv::put("define/${name}/array_integers", $test_array_integers)
  libkv::put("define/${name}/hash", $test_hash)

  libkv::put("define/${name}/bool_with_meta", $test_bool, $test_meta )
  libkv::put("define/${name}/string_with_meta", $test_string, $test_meta)
#  libkv::put("define/${name}/binary_with_meta", $test_binary, $test_meta)
  libkv::put("define/${name}/int_with_meta", $test_integer, $test_meta)
  libkv::put("define/${name}/float_with_meta", $test_float, $test_meta)
  libkv::put("define/${name}/array_strings_with_meta", $test_array_strings, $test_meta)
  libkv::put("define/${name}/array_integers_with_meta", $test_array_integers, $test_meta)
  libkv::put("define/${name}/hash_with_meta", $test_hash, $test_meta)

}
