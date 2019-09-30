class libkv_test::exists(

) {

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  libkv_test::assert_equal(libkv::exists('from_class/boolean'), true, "libkv::exists('from_class/boolean')")
  libkv_test::assert_equal(libkv::exists('from_class/string'), true, "libkv::exists('from_class/string')")
  libkv_test::assert_equal(libkv::exists('from_class/integer'), true, "libkv::exists('from_class/integer')")
  libkv_test::assert_equal(libkv::exists('from_class/float'), true, "libkv::exists('from_class/float')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings'), true, "libkv::exists('from_class/array_strings')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers'), true, "libkv::exists('from_class/array_integers')")
  libkv_test::assert_equal(libkv::exists('from_class/hash'), true, "libkv::exists('from_class/hash')")

  libkv_test::assert_equal(libkv::exists('from_class/boolean_with_meta'), true, "libkv::exists('from_class/boolean_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/string_with_meta'), true, "libkv::exists('from_class/string_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/integer_with_meta'), true, "libkv::exists('from_class/integer_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/float_with_meta'), true, "libkv::exists('from_class/float_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings_with_meta'), true, "libkv::exists('from_class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers_with_meta'), true, "libkv::exists('from_class/array_integers_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/hash_with_meta'), true, "libkv::exists('from_class/hash_with_meta')")

  libkv_test::assert_equal(libkv::exists('from_class/boolean_from_rfunction'), true, "libkv::exists('from_class/boolean_from_rfunction')")

  libkv_test::assert_equal(libkv::exists('from_class/boolean_from_pfunction'), false, "libkv::exists('from_class/boolean_from_pfunction')")
}
