class libkv_test::exists inherits libkv_test::params
{
  # Check for keys with and without metadata for the specified app_id
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv_test::assert_equal(
      libkv::exists($key, $::libkv_test::params::libkv_options),
      true,
      "libkv::exists('${key}')"
    )

    libkv_test::assert_equal(
      libkv::exists("${key}_with_meta", $::libkv_test::params::libkv_options),
      true,
      "libkv::exists('${key}_with_meta')"
    )
  }


  # Check for the key added in own Puppet function call for the specified app_id
  libkv_test::assert_equal(
    libkv::exists(
      "${::libkv_test::params::test_keydir}/boolean_from_pfunction",
      $::libkv_test::params::libkv_options
    ),
    true,
    "libkv::exists('#{::libkv_test::params::test_keydir}}/boolean_from_pfunction')"
  )

  # Check for the key added in own Puppet function call without the specified app_id.
  # Should be in default backend but not the backend for the app_id.
  $_empty_libkv_options = {}
  libkv_test::assert_equal(
    libkv::exists(
      "${::libkv_test::params::test_keydir}/boolean_from_pfunction_no_app_id",
      $_empty_libkv_options
    ),
    true,
    "libkv::exists('#{::libkv_test::params::test_keydir}}/boolean_from_pfunction_no_appid') default backend"
  )

  libkv_test::assert_equal(
    libkv::exists(
      "${::libkv_test::params::test_keydir}/boolean_from_pfunction_no_app_id",
      $::libkv_test::params::libkv_options
    ),
    false,
    "libkv::exists('#{::libkv_test::params::test_keydir}}/boolean_from_pfunction_no_appid') backend for app_id"
  )
}
