# class uses simpkv::list to retrieve list of keys/values/metadata tuples
# for keys in the 'class_keys' backend; fails compilation if the
# retrieved info does match expected
class { 'simpkv_test::list': }

