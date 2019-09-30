class libkv_test::binary_put(
  Binary $test_binary = binary_file('/root/binary_data/input_data'),
  Hash   $test_meta   = { 'some' => 'metadata for binary' }
) {
  libkv::put('from_class/binary', $test_binary)
  libkv::put('from_class/binary_with_meta', $test_binary, $test_meta)
}
