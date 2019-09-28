class libkv_test::exists(

) {

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  libkv_test::assert_equal(libkv::exists('class/bool'), true, "libkv::exists('class/bool')")
  libkv_test::assert_equal(libkv::exists('class/string'), true, "libkv::exists('class/string')")
##  libkv_test::assert_equal(libkv::exists('class/binary'), true, "libkv::exists('class/binary')")
  libkv_test::assert_equal(libkv::exists('class/int'), true, "libkv::exists('class/int')")
  libkv_test::assert_equal(libkv::exists('class/float'), true, "libkv::exists('class/float')")
  libkv_test::assert_equal(libkv::exists('class/array_strings'), true, "libkv::exists('class/array_strings')")
  libkv_test::assert_equal(libkv::exists('class/array_integers'), true, "libkv::exists('class/array_integers')")
  libkv_test::assert_equal(libkv::exists('class/hash'), true, "libkv::exists('class/hash')")

  libkv_test::assert_equal(libkv::exists('class/bool_with_meta'), true, "libkv::exists('class/bool_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/string_with_meta'), true, "libkv::exists('class/string_with_meta')")
##  libkv_test:;assert_equal(libkv::exists('class/binary_with_meta', $test_binary, true, "libkv::exists('class/binary_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/int_with_meta'), true, "libkv::exists('class/int_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/float_with_meta'), true, "libkv::exists('class/float_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/array_strings_with_meta'), true, "libkv::exists('class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/array_integers_with_meta'), true, "libkv::exists('class/array_integet_with_meta')")
  libkv_test::assert_equal(libkv::exists('class/hash_with_meta'), true, "libkv::exists('class/hash_with_meta')")

  libkv_test::assert_equal(libkv::exists('class/bool_from_rfunction'), true, "libkv::exists('class/bool_from_rfunction')")

  libkv_test::assert_equal(libkv::exists('class/bool_from_pfunction'), false, "libkv::exists('class/bool_from_pfunction')")
}
