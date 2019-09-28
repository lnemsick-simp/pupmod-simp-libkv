# DON'T USE THIS!! USE libkv_test::put_rwrapper INSTEAD.
#
# This is a wrapper that will always select the 'default' backend
# when none is specified in `options`.
function libkv_test::put_pwrapper(
  String $key,
  Any    $value,
  Hash   $meta    = {},
  Hash   $options = {}
) {

  #
  # Insert application-specific work
  #

  libkv::put($key, $value, $meta, $options)
}
