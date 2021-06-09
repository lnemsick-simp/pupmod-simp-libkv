# class uses simpkv::exists to verify the existence of keys in
# the 'class_keys' backend; fails compilation if any simpkv::exists
# result doesn't match expected
class { 'simpkv_test::exists': }

