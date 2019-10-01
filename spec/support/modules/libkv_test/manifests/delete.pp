class libkv_test::delete(
  Hash $libkv_options = { 'resource' => 'Class[Libkv_test::Delete]' }
) {

  libkv::delete('from_class/boolean', $libkv_options)
  libkv::delete('from_class/string', $libkv_options)
  libkv::delete('from_class/integer', $libkv_options)
  libkv::delete('from_class/float', $libkv_options)
  libkv::delete('from_class/array_strings', $libkv_options)
  libkv::delete('from_class/array_integers', $libkv_options)
  libkv::delete('from_class/hash', $libkv_options)

  libkv_test::assert_equal(libkv::exists('from_class/boolean', $libkv_options), false, "libkv::exists('from_class/boolean')")
  libkv_test::assert_equal(libkv::exists('from_class/string', $libkv_options), false, "libkv::exists('from_class/string')")
  libkv_test::assert_equal(libkv::exists('from_class/integer', $libkv_options), false, "libkv::exists('from_class/integer')")
  libkv_test::assert_equal(libkv::exists('from_class/float', $libkv_options), false, "libkv::exists('from_class/float')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings', $libkv_options), false, "libkv::exists('from_class/array_strings')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers', $libkv_options), false, "libkv::exists('from_class/array_integers')")
  libkv_test::assert_equal(libkv::exists('from_class/hash', $libkv_options), false, "libkv::exists('from_class/hash')")

  libkv_test::assert_equal(libkv::exists('from_class/boolean_with_meta', $libkv_options), true, "libkv::exists('from_class/boolean_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/string_with_meta', $libkv_options), true, "libkv::exists('from_class/string_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/integer_with_meta', $libkv_options), true, "libkv::exists('from_class/integer_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/float_with_meta', $libkv_options), true, "libkv::exists('from_class/float_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_strings_with_meta', $libkv_options), true, "libkv::exists('from_class/array_strings_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/array_integers_with_meta', $libkv_options), true, "libkv::exists('from_class/array_integers_with_meta')")
  libkv_test::assert_equal(libkv::exists('from_class/hash_with_meta', $libkv_options), true, "libkv::exists('from_class/hash_with_meta')")

  libkv_test::assert_equal(libkv::exists('from_class/boolean_from_pfunction', $libkv_options), true, "libkv::exists('from_class/boolean_from_pfunction')")
}
