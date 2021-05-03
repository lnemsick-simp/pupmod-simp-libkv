# simpkv_test::put calls simpkv::put directly and via a Puppet-language function
# * Stores values of different types.
#   * Binary content is handled elsewhere (a different manifest).
# * Resulting keys
#   * Puppet environment keys with app_id = 'Class[Simpkv_test::Put]'
#     'from_class/boolean'
#     'from_class/string'
#     'from_class/integer'
#     'from_class/float'
#     'from_class/array_strings'
#     'from_class/array_integers'
#     'from_class/hash'
#     'from_class/boolean_with_meta'
#     'from_class/string_with_meta'
#     'from_class/integer_with_meta'
#     'from_class/float_with_meta'
#     'from_class/array_strings_with_meta'
#     'from_class/array_integers_with_meta'
#     'from_class/hash_with_meta'
#     'from_class/boolean_from_pfunction'
#  * Puppet environment keys without an app_id
#     'from_class/boolean_from_pfunction_no_app_id'
#
class { 'simpkv_test::put': }

# These two defines call simpkv::put directly and via the Puppet-language
# function
# * The 'define1' put operations results in the following Puppet environment key
#   with app_id = 'Simpkv_test::Defines::Put[define1]'
#     'from_define/define1/string'
#     'from_define/define1/string_from_pfunction'
# * The 'define2' put operations results in the following Puppet environment key
#   with app_id = 'Simpkv_test::Defines::Put[define2]'
#     'from_define/define2/string'
#     'from_define/define2/string_from_pfunction'
#
simpkv_test::defines::put { 'define2': }

