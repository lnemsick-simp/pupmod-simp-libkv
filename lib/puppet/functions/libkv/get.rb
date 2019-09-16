# Retrieves the value and any metadata stored at `key` from the
#  configured backend.
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::get') do

  # @param key The key to retrieve
  # @param options Hash that specifies global libkv options and/or
  #   the specific backend to use (with or without backend-specific
  #   configuration).  Will be merged with `libkv::options`.
  #
  #   Standard options to specify:
  #
  #   * `softfail`: Boolean.  When set to `true`, this function will return
  #     a result, even when the operation has failed.  Otherwise, the function
  #     will fail when the backend operation fails. Defaults to `false`.
  #   * `environment`: String. When set to a non-empty string, the value is
  #     prepended to the `key` parameter in this operation.  Should only be set
  #     to an empty string when the key being accessed is truly global.
  #     Defaults to the Puppet environment for the node.
  #   * `backend`: String.  Name of the backend to use.  Must be a key in the
  #     'backends' sub-Hash of the merged options Hash.  When absent, this
  #      function will look for a backend whose name matches the calling Class,
  #      specific Define, or Define type.  If no match is found, it will use
  #      the 'default' backend.
  #   * `backends`: Hash.  Hash of backend configuration in which the
  #     key is the name of an instance of a backend.
  #
  #     * Merged hash must have backend configuration for a 'default' key.
  #     * Each backend configuration must be a Hash with the following
  #       required keys:
  #
  #       * `id`:  Unique name for the instance of the backend. (Same backend
  #         type can be configured differently).
  #       * `type`:  Backend type.  Returned value of `<plugin class>.name()`.
  #
  # @raise [ArgumentError] If the key is invalid, the requested backend does
  #   not exist in `libkv::options`, or the plugin for the requested backend
  #   is not available.
  #
  # @raise [LoadError] If the libkv adapter cannot be loaded
  #
  # @raise [RuntimeError] If the backend operation fails, unless
  #   `options['softfail']` is `true`.
  #
  # @return [Enum[Hash,Undef]] Hash containing the value and any metadata upon
  #   success; Undef when the backend operation fails and `options['softfail']`
  #   is `true`
  #
  #   * Hash will have a 'value' key containing the retrieved value
  #   * Hash may have a 'metadata' key containing a Hash with any metadata for
  #     the key
  #
  dispatch :get do
    required_param 'String[1]', :key
    optional_param 'Hash',      :backend_options
  end

  def get(key, backend_options={})
    # key validation difficult to do via a type alias, so validate via function
    call_function('libkv::validate_key', key)

    # add libkv 'extension' to the catalog instance as needed
    call_function('libkv::add_libkv')

    # determine backend configuration using backend_options, `libkv::options`,
    # and the list of backends for which plugins have been loaded
    begin
      merged_options = call_function( 'libkv::get_backend_config',
        backend_options, catalog.libkv.backends)
    rescue RuntimeError => e
      msg = "libkv Configuration Error for libkv::put with key=#{key}: #{e.message}"
      raise ArgumentError.new(msg)
    end

    # use libkv for put operation
    backend_result = catalog.libkv.get(key, merged_options)
    success = backend_result[:success]
    result = nil
    if success
      result = {}
      result['value'] = backend_result[:value]
      if backend_result.has_key?(:metadata)
        result['metadata'] = backend_result[:metadata]
      end
    else
      err_msg =  "libkv::get with key=#{key}: #{backend_result[:err_msg]}"
      if  merged_options['softfail']
        Puppet.warning(err_msg)
      else
        raise(err_msg)
      end
    end

    result
  end
end
