# Validates key conforms to the libkv key specification
#
# * libkv key specification
#   * Key must contain only the following characters:
#     * a-z
#     * A-Z
#     * 0-9
#     * The following special characters: `._:-/`
#   * Key may not contain '/./' or '/../' sequences.
# * Terminates catalog compilation if validation fails.
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::validate_key') do

  # @param key libkv key
  #
  # @return [Nil]
  # @raise [ArgumentError] if validation fails
  #
  # @example Passing
  #   libkv::validate_key('looks/like/a/file/path')
  #   libkv::validate_key('looks/like/a/directory/path/')
  #   libkv::validate_key('simp-simp_snmpd:password.auth')
  #
  # @example Failing
  #   libkv::validate_key('${special}/chars/not/allowed!'}
  #   libkv::validate_key('looks/like/an/./unexpanded/linux/path')
  #   libkv::validate_key('looks/like/another/../unexpanded/linux/path')
  #
  dispatch :validate_key do
    param 'String[1]', :key
  end

  def validate_key(key)
    ws_regex = /[[:space:]]/
    if (key =~ ws_regex)
      msg = "key '#{key}' contains disallowed whitespace"
      raise ArgumentError.new(msg)
    end

    char_regex = /^[a-zA-Z0-9._:\-\/]+$/m
    unless (key =~ char_regex)
      msg = "key '#{key}' contains unsupported characters.  Allowed set=[a-zA-Z0-9._:-/]"
      raise ArgumentError.new(msg)
    end

    dot_regex = /\/\.\.?\//
    if (key =~ dot_regex)
      msg = "key '#{key}' contains disallowed '/./' or '/../' sequence"
      raise ArgumentError.new(msg)
    end
  end

end

