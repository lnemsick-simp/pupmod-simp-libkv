define libkv_test::defines::put(
  String $test_string = 'dstring'
) {

  libkv::put("define/${name}/string", $test_string)

  # Call libkv::put via a Puppet Ruby function - will correctly pick backend
  libkv_test::put_rwrapper("define/${name}/string_from_rfunction", $test_string)
}
