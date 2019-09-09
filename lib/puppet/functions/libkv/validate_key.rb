# Validates key conforms to the libkv key specification
#
# * libkv key specification
#   * Key must contain only the following characters:
#     * a-z
#     * A-Z
#     * 0-9
#     * The following special characters: `._:-/`
#   * Key must start with '/'
#   * Key may not contain '/./' or '/../' sequences.
# * Terminates catalog compilation if validation fails.
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::validate_key') do

  # @param key libkv key
  #
  # @raise [RuntimeError] if validation fails
  #
  # @example Passing
  #   libkv::validate_key('/looks/like/a/file/path')
  #   libkv::validate_key('/looks/like/a/directory/path/')
  #   libkv::validate_key('/simp-simp_snmpd:password.auth')
  #
  # @example Failing
  #   libkv::validate_key('/${special}/chars/not/allowed!'}
  #   libkv::validate_key('missing-initial-slash')
  #   libkv::validate_key('/looks/like/an/./unexpanded/linux/path')
  #   libkv::validate_key('/looks/like/another/../unexpanded/linux/path')
  #
  dispatch :validate_key do
    param 'String[1]', :key
  end

  def validate_key(key)
  end

end

