function libkv_test::put_function(
  String $key,
  Any    $value,
  Hash   $meta
) {

warning("in libkv_test::put_puppet_lang_function")
  libkv::put($key, $value, $meta)
}
