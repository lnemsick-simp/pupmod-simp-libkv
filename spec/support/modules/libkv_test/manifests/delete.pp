class libkv_test::delete inherits libkv_test::params
{
  # Delete keys without metadata for the specified app_id
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv::delete($key, $::libkv_test::params::libkv_options)
  }

  # Verify keys without metadata no longer exist for the specified app_id
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv_test::assert_equal(
      libkv::exists($key, $::libkv_test::params::libkv_options),
      false,
      "libkv::exists('${key}')"
    )
  }

  # Verify keys with metadata still exist for the specified app_id
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv_test::assert_equal(
      libkv::exists("${key}_with_meta", $::libkv_test::params::libkv_options),
      true,
      "libkv::exists('${key}_with_meta')"
    )
  }

  # Verify the key added in own Puppet function call for the specified app_id still exists
  libkv_test::assert_equal(
    libkv::exists(
      "${::libkv_test::params::test_keydir}/boolean_from_pfunction",
      $::libkv_test::params::libkv_options
    ),
    true,
    "libkv::exists('#{::libkv_test::params::test_keydir}}/boolean_from_pfunction')"
  )
}
