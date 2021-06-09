class simpkv_test::put inherits simpkv_test::params
{
  # Add environment keys without metadata for the specified app_id
  $_empty_test_meta = {}
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv::put(
      $key,
      $value,
      $_empty_test_meta,
      $::simpkv_test::params::simpkv_options
    )
  }


  # Add environment keys with metadata for the specified app_id
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv::put(
      "${key}_with_meta",
      $value,
      $::simpkv_test::params::test_meta,
      $::simpkv_test::params::simpkv_options
    )
  }

  # Add environment key within our own Puppet function call for the specified app_id
  simpkv_test::put_pwrapper(
    "${::simpkv_test::params::test_keydir}/boolean_from_pfunction",
    $::simpkv_test::params::test_bool,
    $::simpkv_test::params::simpkv_options
  )

  # Add environment key within our own Puppet function call but without the app_id.
  # This key will be stored in the default backend.
  $_empty_simpkv_options = {}
  simpkv_test::put_pwrapper(
    "${::simpkv_test::params::test_keydir}/boolean_from_pfunction_no_app_id",
    $::simpkv_test::params::test_bool,
    $_empty_simpkv_options
  )

  # FIXME Add global keys
}
