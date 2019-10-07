class libkv_test::list inherits libkv_test::params
{
  $_expected = {
    $::libkv_test::params::test_bool_key                          => { 'value' => $::libkv_test::params::test_bool },
    $::libkv_test::params::test_string_key                        => { 'value' => $::libkv_test::params::test_string },
    $::libkv_test::params::test_integer_key                       => { 'value' => $::libkv_test::params::test_integer },
    $::libkv_test::params::test_float_key                         => { 'value' => $::libkv_test::params::test_float },
    $::libkv_test::params::test_array_strings_key                 => { 'value' => $::libkv_test::params::test_array_strings },
    $::libkv_test::params::test_array_integers_key                => { 'value' => $::libkv_test::params::test_array_integers },
    $::libkv_test::params::test_hash_key                          => { 'value' => $::libkv_test::params::test_hash },

    "${::libkv_test::params::test_bool_key}_with_meta"            => { 'value' => $::libkv_test::params::test_bool, 'metadata' => $::libkv_test::params::test_meta },
    "${::libkv_test::params::test_string_key}_with_meta"          => { 'value' => $::libkv_test::params::test_string, 'metadata' => $::libkv_test::params::test_meta },
    "${::libkv_test::params::test_integer_key}_with_meta"         => { 'value' => $::libkv_test::params::test_integer, 'metadata' => $::libkv_test::params::test_meta },
    "${::libkv_test::params::test_float_key}_with_meta"           => { 'value' => $::libkv_test::params::test_float, 'metadata' => $::libkv_test::params::test_meta },
    "${::libkv_test::params::test_array_strings_key}_with_meta"   => { 'value' => $::libkv_test::params::test_array_strings, 'metadata' => $::libkv_test::params::test_meta },
    "${::libkv_test::params::test_array_integers_key}_with_meta"  => { 'value' => $::libkv_test::params::test_array_integers, 'metadata' => $::libkv_test::params::test_meta },
    "${::libkv_test::params::test_hash_key}_with_meta"            => { 'value' => $::libkv_test::params::test_hash, 'metadata' => $::libkv_test::params::test_meta },

    "${::libkv_test::params::test_keydir}/boolean_from_pfunction" => { 'value' => $::libkv_test::params::test_bool }
  }

  libkv_test::assert_equal(
    libkv::list($::libkv_test::params::test_keydir, $::libkv_test::params::libkv_options),
    $_expected,
    "libkv::list('${::libkv_test::params::test_keydir}')"
  )
}
