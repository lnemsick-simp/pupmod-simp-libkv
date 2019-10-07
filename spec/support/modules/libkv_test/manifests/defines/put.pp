define libkv_test::defines::put(
  String $test_string    = 'dstring',
  Hash   $test_meta      = {},
  Hash   $libkv_options  = { 'app_id' => "Libkv_test::Defines::Put[${name}]" }
) {

  libkv::put("from_define/${name}/string", $test_string, $test_meta,  $libkv_options)
  libkv_test::put_pwrapper("from_define/${name}/string_from_pfunction", $test_string, $libkv_options, $test_meta)
}
