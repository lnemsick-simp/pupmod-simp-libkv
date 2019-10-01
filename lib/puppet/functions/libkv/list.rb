# Returns a list of all keys in a folder.
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::list') do

  # @param keydir The key folder to be removed
  # @param options Hash that specifies global libkv options and/or the specific
  #   backend to use (with or without backend-specific configuration).
  #   Will be merged with `libkv::options`.
  #
  #   Supported options keys:
  #
  #   * `backends`: Hash.  Hash of backend configurations
  #
  #     * Each backend configuration in the merged options Hash must be
  #       a Hash that has the following keys:
  #
  #       * `type`:  Backend type.
  #       * `id`:  Unique name for the instance of the backend. (Same backend
  #         type can be configured differently).
  #
  #      * Other keys for configuration specific to the backend may also be
  #        present.
  #
  #   * `backend`: String.  Name of the backend to use.
  #
  #     * When present, must match a key in the `backends` option of the
  #       merged options Hash.
  #     * When absent and not specified in `libkv::options`, this function
  #       will look for a 'default.xxx' backend whose name matches the
  #       `resource` option.  This is typically the catalog resource id of the
  #       calling Class, specific defined type instance, or defined type.
  #       If no match is found, it will use the 'default' backend.
  #
  #   * `environment`: String.  Puppet environment to prepend to keys.
  #
  #     * When set to a non-empty string, it is prepended to the key used in
  #       the backend operation.
  #     * Should only be set to an empty string when the key being accessed is
  #       truly global.
  #     * Defaults to the Puppet environment for the node.
  #
  #   * `resource`: String.  Name of the Puppet resource initiating this libkv
  #     operation
  #
  #     * Required when `backend` is not specified and you want to be able
  #       to use more than the `default` backend.
  #     * String should be resource as it would appear in the catalog or
  #       some application grouping id
  #
  #       * 'Class[<class>]' for a class, e.g.  'Class[Mymodule::Myclass]'
  #       * '<Defined type>[<instance>]' for a defined type instance, e.g.,
  #         'Mymodule::Mydefine[myinstance]'
  #
  #     * Catalog resource id cannot be reliably determined automatically.
  #       Appropriate scope is not necessarily available when a libkv function
  #       is called within any other function.  This is problematic for heavily
  #       used Puppet built-in functions such as `each`.
  #
  #  * `softfail`: Boolean. Whether to ignore libkv operation failures.
  #
  #    * When `true`, this function will return a result even when the operation
  #      failed at the backend.
  #    * When `false`, this function will fail when the backend operation failed.
  #    * Defaults to `false`.
  #
  # @raise [LoadError] If the libkv adapter cannot be loaded
  #
  # @raise [RuntimeError] If the backend operation fails, unless 'softfail' is
  #   `true` in the merged backend options.
  #
  # @return [Enum[Hash,Undef]] Hash containing the key/info pairs upon
  #   success; Undef when the backend operation fails and 'softfail' is `true`
  #   in the merged backend options
  #
  #   * Each key in the Hash is a key found in the folder
  #   * Each value in the Hash is a Hash with a 'value' key and an optional 'metadata'
  #     key.
  #
  dispatch :list do
    required_param 'String[1]', :keydir
    optional_param 'Hash',      :options
  end

  def list(keydir, options={})
    # key validation difficult to do via a type alias, so validate via function
    call_function('libkv::validate_key', keydir)

    # add libkv 'extension' to the catalog instance as needed
    call_function('libkv::add_libkv')

    # determine backend configuration using options, `libkv::options`,
    # and the list of backends for which plugins have been loaded
    begin
      resource = options.has_key?('resource') ?  options['resource'] : 'unknown'
      catalog = closure_scope.find_global_scope.catalog
      merged_options = call_function( 'libkv::get_backend_config', options,
        catalog.libkv.backends, resource)
    rescue ArgumentError => e
      msg = "libkv Configuration Error for libkv::list with keydir='#{keydir}': #{e.message}"
      raise ArgumentError.new(msg)
    end

    # use libkv for list operation
    backend_result = catalog.libkv.list(keydir, merged_options)

    result = backend_result[:result]
    if result.nil?
      err_msg =  "libkv Error for libkv::list with keydir='#{keydir}': #{backend_result[:err_msg]}"
      if merged_options['softfail']
        Puppet.warning(err_msg)
      else
        raise(err_msg)
      end
    else
      result = {}
      backend_result[:result].each do |key,info|
         result[key] = { 'value' => info[:value] }
         unless info[:metadata].empty?
          result[key]['metadata'] = info[:metadata]
        end
      end
    end

    result
  end
end
