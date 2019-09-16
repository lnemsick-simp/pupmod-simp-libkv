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
  # @return [Hash]] merged libkv options that will have the backend to use
  #   specified by 'backend'
  #
  # @raise [RuntimeError] if appropriate backend configuration cannot be found
  #
  dispatch :get_backend_config do
    param 'Hash',  :options
    param 'Array', :backends
  end

  def get_backend_config(options, backends)
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

    unless (merged_options.has_key?('backends') &&
        merged_options['backends'].is_a?(Hash) &&
        merged_options['backends'].has_key?(backend) &&
        merged_options['backends'][backend].has_key?('id') &&
        merged_options['backends'][backend].has_key?('type'))
      raise("No backend #{backend} with 'id' and 'type' attributes has been configured")
    elsif
      !backends.include?(merged_options['backends'][backend]['type'])
      raise("Backend plugin '#{merged_options['backends'][backend]['type']}' not available")
    else
      #FIXME Do we want to make sure all backends have unique 'id' + 'type' here?
      # Where else would we do the validation?  Perhaps in libkv::add_libkv?
    end

    unless merged_options.has_key?('environment')
      merged_options['environment'] = closure_scope.compiler.environment.to_s
    end

    merged_options['environment'] = '' if merged_options['environment'].nil?

    # Return the full set of options (not just the specific backend options),
    # so that any global options are also available
    return merged_options
  end
