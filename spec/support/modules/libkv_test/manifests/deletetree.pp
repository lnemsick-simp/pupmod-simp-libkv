class libkv_test::deletetree(
) {


  libkv::deletetree('class')

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  libkv_test::assert_equal(libkv::exists('class/bool'), false, "libkv::exists('class/bool')")
  libkv_test::assert_equal(libkv::exists('class/string'), false, "libkv::exists('class/string')")
##  libkv_test::assert_equal(libkv::exists('class/binary'), false, "libkv::exists('class/binary')")
  libkv_test::assert_equal(libkv::exists('class/int'), false, "libkv::exists('class/int')")
  libkv_test::assert_equal(libkv::exists('class/float'), false, "libkv::exists('class/float')")
  libkv_test::assert_equal(libkv::exists('class/array_strings'), false, "libkv::exists('class/array_strings')")
  libkv_test::assert_equal(libkv::exists('class/array_integers'), false, "libkv::exists('class/array_integers')")
  libkv_test::assert_equal(libkv::exists('class/hash'), false, "libkv::exists('class/hash')")

  libkv_test::assert_equal(libkv::exists('class/bool_with_meta'), false, "libkv::exists('class/bool_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/string_with_meta'), false, "libkv::exists('class/string_with_meta')")
##  libkv_test:;assert_equal(libkv::exists('class/binary_with_meta', $test_binary, false, "libkv::exists('class/binary_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/int_with_meta'), false, "libkv::exists('class/int_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/float_with_meta'), false, "libkv::exists('class/float_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/array_strings_with_meta'), false, "libkv::exists('class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/array_integers_with_meta'), false, "libkv::exists('class/array_integet_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/hash_with_meta'), false, "libkv::exists('class/hash_with_meta')")

  libkv_test::assert_equal(libkv::exists('class/bool_from_rfunction'), false, "libkv::exists('class/bool_from_rfunction')")
}
