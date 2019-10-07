class libkv_test::get inherits libkv_test::params
{
  # Get keys with and without metadata for the specified app_id
  $_empty_test_meta = {}
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv_test::assert_equal(
      libkv::get($key, $::libkv_test::params::libkv_options),
      { 'value' => $value },
      "libkv::get('${key}')"
    )

    libkv_test::assert_equal(
      libkv::get("${key}_with_meta", $::libkv_test::params::libkv_options),
      { 'value' => $value, 'metadata' => $::libkv_test::params::test_meta },
      "libkv::get('${key}_with_meta')"
    )
  }

  # Get key added in own Puppet function call for the specified app_id
  libkv_test::assert_equal(
    libkv::get(
      "${::libkv_test::params::test_keydir}/boolean_from_pfunction",
      $::libkv_test::params::libkv_options
    ),
    { 'value' => $::libkv_test::params::test_bool },
    "libkv::get('${::libkv_test::params::test_keydir}/boolean_from_pfunction')"
   )
}
