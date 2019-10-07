class libkv_test::deletetree inherits libkv_test::params
{
  # Delete parent dir of keys for the specified app_id
  libkv::deletetree($::libkv_test::params::test_keydir, $::libkv_test::params::libkv_options)

  # Verify keys with and without metadata no longer exist for the specified app_id
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv_test::assert_equal(
      libkv::exists($key, $::libkv_test::params::libkv_options),
      false,
      "libkv::exists('${key}')"
    )

    libkv_test::assert_equal(
      libkv::exists("${key}_with_meta", $::libkv_test::params::libkv_options),
      false,
      "libkv::exists('${key}_with_meta')"
    )
  }

  # Verify the key added in own Puppet function call for the specified app_id no longer exists
  libkv_test::assert_equal(
    libkv::exists(
      "${::libkv_test::params::test_keydir}/boolean_from_pfunction",
      $::libkv_test::params::libkv_options
    ),
    false,
    "libkv::exists('#{::libkv_test::params::test_keydir}}/boolean_from_pfunction')"
  )
}
