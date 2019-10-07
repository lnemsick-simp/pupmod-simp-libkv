class libkv_test::put inherits libkv_test::params
{
  # Add keys without metadata for the specified app_id
  $_empty_test_meta = {}
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv::put(
      $key,
      $value,
      $_empty_test_meta,
      $::libkv_test::params::libkv_options
    )
  }


  # Add keys with metadata for the specified app_id
  $::libkv_test::params::key_value_pairs.each |$key, $value| {
    libkv::put(
      "${key}_with_meta",
      $value,
      $::libkv_test::params::test_meta,
      $::libkv_test::params::libkv_options
    )
  }

  # Add key within our own Puppet function call for the specified app_id
  libkv_test::put_pwrapper(
    "${::libkv_test::params::test_keydir}/boolean_from_pfunction",
    $::libkv_test::params::test_bool,
    $::libkv_test::params::libkv_options
  )

  # Add key within our own Puppet function call but without the app_id.
  # This key will be stored in the default backend.
  $_empty_libkv_options = {}
  libkv_test::put_pwrapper(
    "${::libkv_test::params::test_keydir}/boolean_from_pfunction_no_app_id",
    $::libkv_test::params::test_bool,
    $_empty_libkv_options
  )
}
