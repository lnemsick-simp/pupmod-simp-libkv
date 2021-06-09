# class uses simpkv::get to retrieve values with/without metadata for
# keys in the 'class_keys' backend; fails compilation if any
# retrieved info does match expected
class { 'simpkv_test::get': }

