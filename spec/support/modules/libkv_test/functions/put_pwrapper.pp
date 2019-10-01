# Puppet language wrapper function for libkv::put
#
# We force the user to pass in options, so that libkv::put
# doesn't always assume the backend in `default`!
function libkv_test::put_pwrapper(
  String $key,
  Any    $value,
  Hash   $options,
  Hash   $meta     = {},
) {

  #
  # Insert application-specific work
  #

  libkv::put($key, $value, $meta, $options)
}
