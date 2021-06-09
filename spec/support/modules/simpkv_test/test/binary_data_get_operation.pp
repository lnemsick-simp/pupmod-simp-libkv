# class uses simpkv::get to retrieve binary data for Binary type variables
# and to persist new files with binary content; fails compilation if any
# retrieved info does match expected
class { 'simpkv_test::binary_get': }

