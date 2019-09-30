function libkv_test::assert_equal(
  Any    $actual,
  Any    $expected,
  String $message
) {

  info("Checking results for ${message}")

  if ($actual != $expected) {
    fail("Expected '${expected}'; got '${actual}' for ${message}")
  }
}
