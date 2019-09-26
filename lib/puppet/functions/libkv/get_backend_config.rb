# Create merged backend configuration and then validate it.
#
# The `options` argument is merged with `libkv::options` Hiera and global libkv
# defaults. Validation includes the following checks:
#
# * configuration for the selected backend exists
# * the plugin for the selected backend has been loaded
# * different configuration for a specific plugin instance does not exist
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::get_backend_config') do

  # @param options Hash that specifies libkv backend options to be merged with
  #   `libkv::options`.
  #
  # @param backends List of backends for which plugins have been successfully
  #   loaded.
  #
  # @param resource_info Resource string for the Puppet class or define that has
  #   called the libkv function.
  #
  #   * Examples: 'Class[Mymodule::Myclass]' or 'Mymodule::Mydefine[myinstance]'
  #   * Used to determine the default backend to use, when none is specified
  #     in the libkv options Hash
  #
  # @return [Hash]] merged libkv options that will have the backend to use
  #   specified by 'backend'
  #
  # @raise [ArgumentError] if merged configuration fails validation
  #
  # @see libkv::validate_backend_config
  #
  dispatch :get_backend_config do
    param 'Hash',      :options
    param 'Array',     :backends
    param 'String[1]', :resource_info
  end

  def get_backend_config(options, backends, resource_info)
    merged_options = merge_options(options, resource_info)
    call_function('libkv::validate_backend_config', merged_options, backends)
    return merged_options
  end

  # merge options and set defaults for 'backend', 'environment', and 'softfail'
  # when missing
  def merge_options(options, resource_info)
    require 'deep_merge'
    # deep_merge will not work with frozen options, so make a deep copy
    # (options.dup is a shallow copy of contained Hashes)
    options_dup = Marshal.load(Marshal.dump(options))

    merged_options = call_function('lookup', 'libkv::options', { 'default_value' => {} })
    merged_options.deep_merge!(options_dup)

    backend = nil
    if merged_options.has_key?('backend')
      backend = merged_options['backend']
    else
      backend = 'default'
      if merged_options.has_key?('backends')
        defaults = merged_options['backends'].keys
        defaults.delete_if { |name| !name.start_with?('default') }
        full_default = "default.#{resource_info}"
        partial_default = full_default.split('[').first
        if defaults.include?(full_default)
          backend = full_default
        elsif defaults.include?(partial_default)
          backend = partial_default
        end
      end
      merged_options['backend'] = backend
    end

    unless merged_options.has_key?('softfail')
      merged_options['softfail'] = false
    end

    unless merged_options.has_key?('environment')
      merged_options['environment'] = closure_scope.compiler.environment.to_s
    end

    merged_options['environment'] = '' if merged_options['environment'].nil?
    merged_options
  end
end

