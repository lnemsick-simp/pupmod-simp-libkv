# class uses simpkv::deletetree to remove the remaining keys in the 'class_keys'
# backend and the simpkv::exists to verify all keys are gone; fails compilation
# if any keys remain
class { 'simpkv_test::deletetree': }

