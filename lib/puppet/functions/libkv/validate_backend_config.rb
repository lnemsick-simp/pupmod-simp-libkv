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
  # @return [Nil]
  # @raise [ArgumentError] if a backend has not been specified, appropriate
  #   configuration for a specified backend cannot be found, or different
  #   backend configurations are provided for the same ['type', 'id'] pair.
  #
  dispatch :validate_backend_config do
    # Can't use a fully-defined Struct, since the parts of the Hash
    # specifying individual plugin config may have plugin-specific keys
    param 'Hash',  :options
    param 'Array', :backends
  end

  def validate_backend_config(options, backends)
    unless options.has_key?('backend')
      msg = "'backend' not specified in libkv configuration: #{options}"
      raise ArgumentError.new(msg)
    end

    backend = options['backend']

    unless options.has_key?('backends')
      msg = "'backends' not specified in libkv configuration: #{options}"
      raise ArgumentError.new(msg)
    end

    unless options['backends'].is_a?(Hash)
      msg = "'backends' in libkv configuration is not a Hash: #{options}"
      raise ArgumentError.new(msg)
    end

    unless (
      options['backends'].has_key?(options['backend']) &&
      options['backends'][backend].is_a?(Hash) &&
      options['backends'][backend].has_key?('id') &&
      options['backends'][backend].has_key?('type')
    )
      msg = "No libkv backend '#{backend}' with 'id' and 'type' attributes has been configured: #{options}"
      raise ArgumentError.new(msg)
    end

    unless backends.include?(options['backends'][backend]['type'])
      msg = "libkv backend plugin '#{options['backends'][backend]['type']}' not available. Valid plugins = #{backends}"
      raise ArgumentError.new(msg)
    end

    # plugin instances are uniquely defined by the <type,id> pair, not name.
    # Make sure all backend configurations for a <type,id> pair have the same
    # configuration.
    backend_instances = {}
    options['backends'].each do |name, config|
      instance_id = "#{config['type']}/#{config['id']}"
      if backend_instances.has_key?(instance_id)
        unless backend_instances[instance_id] == config
          msg = 'libkv config contains different backend configs for ' +
            "type=#{config['type']} id=#{config['id']}: #{options}"
          raise ArgumentError.new(msg)
        end
      else
        backend_instances[instance_id] = config
      end
   end
  end
end
