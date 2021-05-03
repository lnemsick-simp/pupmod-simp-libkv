# class uses simpkv::delete to remove a subset of keys in the 'class_keys'
# backend and the simpkv::exists to verify they are gone but the other keys
# are still present; fails compilation if any removed keys still exist or
# any preserved keys have been removed
class { 'simpkv_test::delete': }
