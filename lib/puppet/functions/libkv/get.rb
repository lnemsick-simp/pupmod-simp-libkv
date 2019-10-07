# Retrieves the value and any metadata stored at `key` from the
#  configured backend.
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::get') do

  # @param key The key to retrieve. Must conform to the following:
  #
  #   * Key must contain only the following characters:
  #
  #     * a-z
  #     * A-Z
  #     * 0-9
  #     * The following special characters: `._:-/`
  #
  #   * Key may not contain '/./' or '/../' sequences.
  #
  # @param options libkv configuration that will be merged with
  #   `libkv::options`.  All keys are optional.
  #
  # @option options [String] 'app_id'
  #   Specifies an application name that can be used to identify which backend
  #   configuration to use via fuzzy name matching, in the absence of the
  #   `backend` option.
  #
  #     * More flexible option than `backend`.
  #     * Useful for grouping together libkv function calls found in different
  #       catalog resources.
  #     * When specified and the `backend` option is absent, the backend will be
  #       selected preferring a backend in the merged `backends` option whose
  #       name exactly matches the `app_id`, followed by the longest backend
  #       name that matches the beginning of the `app_id`, followed by the
  #       `default` backend.
  #     * When absent and the `backend` option is also absent, this function
  #       will use the `default` backend.
  #
  # @option options [String] 'backend'
  #   Definitive name of the backend to use.
  #
  #     * Takes precedence over `app_id`.
  #     * When present, must match a key in the `backends` option of the
  #       merged options Hash or the function will fail.
  #     * When absent in the merged options, this function will select
  #       the backend as described in the `app_id` option.
  #
  # @option options [Hash] 'backends'
  #   Hash of backend configurations
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
  # @option options [String] 'environment'
  #   Puppet environment to prepend to keys.
  #
  #     * When set to a non-empty string, it is prepended to the key used in
  #       the backend operation.
  #     * Should only be set to an empty string when the key being accessed is
  #       truly global.
  #     * Defaults to the Puppet environment for the node.
  #
  # @option options [Boolean] 'softfail'
  #   Whether to ignore libkv operation failures.
  #
  #     * When `true`, this function will return a result even when the
  #       operation failed at the backend.
  #     * When `false`, this function will fail when the backend operation
  #       failed.
  #     * Defaults to `false`.
  #
  # @raise ArgumentError If the key or merged backend config is invalid
  #
  # @raise LoadError If the libkv adapter cannot be loaded
  #
  # @raise RuntimeError If the backend operation fails, unless 'softfail' is
  #   `true` in the merged backend options.
  #
  # @return [Enum[Hash,Undef]] Hash containing the value and any metadata upon
  #   success; Undef when the backend operation fails and 'softfail' is `true`
  #   in the merged backend options
  #
  #   * Hash will have a 'value' key containing the retrieved value
  #   * Hash may have a 'metadata' key containing a Hash with any metadata for
  #     the key
  #
  # @example Retrieve the value and any metadata for a key in the default backend
  #  $result = libkv::get("database/${facts['fqdn']}")
  #  class { 'wordpress':
  #    db_host => $result['value']
  #  }
  #
  # @example Retrieve the value and any metadata for a key in the backend servicing an application id
  #  $result = libkv::get("database/${facts['fqdn']}", { 'app_id' => 'myapp' })
  #  class { 'wordpress':
  #    db_host => $result['value']
  #  }
  #
  dispatch :get do
    required_param 'String[1]', :key
    optional_param 'Hash',      :options
  end

  def get(key, options={})
    # key validation difficult to do via a type alias, so validate via function
    call_function('libkv::support::key::validate', key)

    # load libkv and add libkv 'extension' to the catalog instance as needed
    call_function('libkv::support::load')

    # determine backend configuration using options, `libkv::options`,
    # and the list of backends for which plugins have been loaded
    begin
      catalog = closure_scope.find_global_scope.catalog
      merged_options = call_function( 'libkv::support::config::merge', options,
        catalog.libkv.backends)
    rescue ArgumentError => e
      msg = "libkv Configuration Error for libkv::get with key='#{key}': #{e.message}"
      raise ArgumentError.new(msg)
    end

    # use libkv for get operation
    backend_result = catalog.libkv.get(key, merged_options)

    result = backend_result[:result]
    if result.nil?
      err_msg =  "libkv Error for libkv::get with key='#{key}': #{backend_result[:err_msg]}"
      if merged_options['softfail']
        Puppet.warning(err_msg)
      else
        raise(err_msg)
      end
    else
      result = { 'value' => backend_result[:result][:value] }
      unless backend_result[:result][:metadata].empty?
        result['metadata'] = backend_result[:result][:metadata]
      end
    end

    result
  end
end
