class libkv_test::put(
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

  libkv::put('class/bool', $test_bool)
  libkv::put('class/string', $test_string)
#  libkv::put('class/binary', $test_binary)
  libkv::put('class/int', $test_integer)
  libkv::put('class/float', $test_float)
  libkv::put('class/array_strings', $test_array_strings)
  libkv::put('class/array_integers', $test_array_integers)
  libkv::put('class/hash', $test_hash)

  libkv::put('class/bool_with_meta', $test_bool, $test_meta )
  libkv::put('class/string_with_meta', $test_string, $test_meta)
#  libkv::put('class/binary_with_meta', $test_binary, $test_meta)
  libkv::put('class/int_with_meta', $test_integer, $test_meta)
  libkv::put('class/float_with_meta', $test_float, $test_meta)
  libkv::put('class/array_strings_with_meta', $test_array_strings, $test_meta)
  libkv::put('class/array_integers_with_meta', $test_array_integers, $test_meta)
  libkv::put('class/hash_with_meta', $test_hash, $test_meta)



  libkv_test::defines::put { 'define1': }
  libkv_test::defines::put { 'define2': }

  $_class_keys = libkv::list('class')
  $_define1_keys = libkv::list('define/define1')
  $_define2_keys = libkv::list('define/define2')
  simplib::inspect('_class_keys')
  simplib::inspect('_define1_keys')
  simplib::inspect('_define2_keys')
}
