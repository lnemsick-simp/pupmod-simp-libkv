class libkv_test::delete(
) {

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  libkv::delete('from_class/bool')
  libkv::delete('from_class/string')
  libkv::delete('from_class/binary')
  libkv::delete('from_class/int')
  libkv::delete('from_class/float')
  libkv::delete('from_class/array_strings')
  libkv::delete('from_class/array_integers')
  libkv::delete('from_class/hash')

  libkv_test::assert_equal(libkv::exists('from_class/bool'), false, "libkv::exists('from_class/bool')")
  libkv_test::assert_equal(libkv::exists('from_class/string'), false, "libkv::exists('from_class/string')")
  libkv_test::assert_equal(libkv::exists('from_class/binary'), false, "libkv::exists('from_class/binary')")
  libkv_test::assert_equal(libkv::exists('from_class/int'), false, "libkv::exists('from_class/int')")
  libkv_test::assert_equal(libkv::exists('from_class/float'), false, "libkv::exists('from_class/float')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings'), false, "libkv::exists('from_class/array_strings')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers'), false, "libkv::exists('from_class/array_integers')")
  libkv_test::assert_equal(libkv::exists('from_class/hash'), false, "libkv::exists('from_class/hash')")

  libkv_test::assert_equal(libkv::exists('from_class/bool_with_meta'), true, "libkv::exists('from_class/bool_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/string_with_meta'), true, "libkv::exists('from_class/string_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/binary_with_meta', $test_binary, true, "libkv::exists('from_class/binary_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/int_with_meta'), true, "libkv::exists('from_class/int_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/float_with_meta'), true, "libkv::exists('from_class/float_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings_with_meta'), true, "libkv::exists('from_class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers_with_meta'), true, "libkv::exists('from_class/array_integet_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/hash_with_meta'), true, "libkv::exists('from_class/hash_with_meta')")

  libkv_test::assert_equal(libkv::exists('from_class/bool_from_rfunction'), true, "libkv::exists('from_class/bool_from_rfunction')")
}
