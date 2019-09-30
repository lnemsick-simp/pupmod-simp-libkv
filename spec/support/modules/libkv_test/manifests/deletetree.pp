class libkv_test::deletetree(
) {


  libkv::deletetree('from_class')

  # Do not try to put these in an each block...you will end up with
  # the default backend because the class resource will be 'Class[main]'

  libkv_test::assert_equal(libkv::exists('from_class/boolean'), false, "libkv::exists('from_class/boolean')")
  libkv_test::assert_equal(libkv::exists('from_class/string'), false, "libkv::exists('from_class/string')")
  libkv_test::assert_equal(libkv::exists('from_class/integer'), false, "libkv::exists('from_class/integer')")
  libkv_test::assert_equal(libkv::exists('from_class/float'), false, "libkv::exists('from_class/float')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings'), false, "libkv::exists('from_class/array_strings')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers'), false, "libkv::exists('from_class/array_integers')")
  libkv_test::assert_equal(libkv::exists('from_class/hash'), false, "libkv::exists('from_class/hash')")

  libkv_test::assert_equal(libkv::exists('from_class/boolean_with_meta'), false, "libkv::exists('from_class/boolean_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/string_with_meta'), false, "libkv::exists('from_class/string_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/integer_with_meta'), false, "libkv::exists('from_class/integer_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/float_with_meta'), false, "libkv::exists('from_class/float_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings_with_meta'), false, "libkv::exists('from_class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers_with_meta'), false, "libkv::exists('from_class/array_integers_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/hash_with_meta'), false, "libkv::exists('from_class/hash_with_meta')")

  libkv_test::assert_equal(libkv::exists('from_class/boolean_from_rfunction'), false, "libkv::exists('from_class/boolean_from_rfunction')")
}
