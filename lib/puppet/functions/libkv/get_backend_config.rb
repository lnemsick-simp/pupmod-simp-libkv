# Determine backend configuration using the options parameter,
# `libkv::options` Hiera, and the list of supported backends.
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
  #   * Examples: 'Class[Myclass]' or 'Mydefine[name]'
  #   * Used to determine the default backend to use, when none is specified
  #     in the libkv options Hash
  #
  # @return [Hash]] merged libkv options that will have the backend to use
  #   specified by 'backend'
  #
  # @raise [RuntimeError] if appropriate backend configuration cannot be found
  #
  dispatch :get_backend_config do
    param 'Hash',      :options
    param 'Array',     :backends
    param 'String[1]', :resource_info
  end

  def get_backend_config(options, backends, resource_info)
    merged_options = merge_options(options)
    call_function('libkv::validate_options', merged_options, backends)
    return merged_options
  end

  # merge options and set defaults for 'environment' and 'backend' when missing
  def merge_options(options)
    merged_options = call_function('lookup', 'libkv::options', { 'default_value' => {} })
    merged_options.deep_merge!(options)

    backend = nil
    if merged_options.has_key?('backend')
      backend = merged_options['backend']
    else
      #FIXME Need to look up calling class/define and then search for it
      # in merged_options['backends']
      backend = 'default'
      merged_options['backend'] = backend
    end

    unless merged_options.has_key?('environment')
      merged_options['environment'] = closure_scope.compiler.environment.to_s
    end

    merged_options['environment'] = '' if merged_options['environment'].nil?
  end
end

