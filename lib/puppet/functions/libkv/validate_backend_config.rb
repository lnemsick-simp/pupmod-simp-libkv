# Validate backend configuration
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::validate_backend_config') do

  # @param options Hash that specifies libkv backend options
  #
  # @param backends List of backends for which plugins have been successfully
  #   loaded.
  #
  # @raise [RuntimeError] if a backend has not been specified or
  #   appropriate configuration for a specified backend cannot be found
  #
  dispatch :validate_backend_config do
    # Can't use a fully-defined Struct, since the parts of the Hash
    # specifying individual plugin config may have plugin-specific keys
    param 'Hash',  :options
    param 'Array', :backends
  end

  def validate_backend_config(options, backends)
    unless options.has_key?('backend')
      raise("'backend' not specified in libkv configuration: #{options}")
    end

    backend = options['backend']

    unless options.has_key?('backends')
      raise("'backends' not specified in libkv configuration: #{options}")
    end

    unless options['backends'].is_a?(Hash)
      raise("'backends' in libkv configuration is not a Hash: #{options}")
    end

    unless (
      options['backends'].has_key?(options['backend']) &&
      options['backends'][backend].is_a?(Hash) &&
      options['backends'][backend].has_key?('id') &&
      options['backends'][backend].has_key?('type')
    )
      raise("No libkv backend '#{backend}' with 'id' and 'type' attributes has been configured: #{options}")
    end

    unless backends.include?(options['backends'][backend]['type'])
      raise("libkv backend plugin '#{options['backends'][backend]['type']}' not available. Valid plugins = #{backends}")
    end

    # make sure each plugin configuration maps to a unique plugin instance
    backend_instances = []
    unless
      options['backends'].each do |name, config|
        instance_id = "#{config['type']}/#{config['id']}"
        if backend_instances.include?(instance_id)
          raise("libkv config contains multiple backend configs for type=#{config['type']} id=#{config['id']}: #{options}")
        end
        backend_instances << instance_id
      end
    end
  end
end
