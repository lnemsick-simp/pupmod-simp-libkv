class libkv_test::deletetree(
) {


  libkv::deletetree('from_class')

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  libkv_test::assert_equal(libkv::exists('from_class/bool'), false, "libkv::exists('from_class/bool')")
  libkv_test::assert_equal(libkv::exists('from_class/string'), false, "libkv::exists('from_class/string')")
  libkv_test::assert_equal(libkv::exists('from_class/binary'), false, "libkv::exists('from_class/binary')")
  libkv_test::assert_equal(libkv::exists('from_class/int'), false, "libkv::exists('from_class/int')")
  libkv_test::assert_equal(libkv::exists('from_class/float'), false, "libkv::exists('from_class/float')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings'), false, "libkv::exists('from_class/array_strings')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers'), false, "libkv::exists('from_class/array_integers')")
  libkv_test::assert_equal(libkv::exists('from_class/hash'), false, "libkv::exists('from_class/hash')")

  libkv_test::assert_equal(libkv::exists('from_class/bool_with_meta'), false, "libkv::exists('from_class/bool_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/string_with_meta'), false, "libkv::exists('from_class/string_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/binary_with_meta', $test_binary, false, "libkv::exists('from_class/binary_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/int_with_meta'), false, "libkv::exists('from_class/int_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/float_with_meta'), false, "libkv::exists('from_class/float_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings_with_meta'), false, "libkv::exists('from_class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers_with_meta'), false, "libkv::exists('from_class/array_integet_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/hash_with_meta'), false, "libkv::exists('from_class/hash_with_meta')")

  libkv_test::assert_equal(libkv::exists('from_class/bool_from_rfunction'), false, "libkv::exists('from_class/bool_from_rfunction')")
}
