# @summary libkv adapter
#
# Anonymous class that does the following
# - Loads libkv backend plugins as anonymous classes
#   - Prevents cross-environment Ruby code contamination
#     in the puppetserver
#   - Sadly, makes code more difficult to understand and
#     code sharing tricky
# - Instantiates plugin instances as they are needed
#   - Unique instance per plugin {id,type} pair requested
# - Normalizes key values
# - Serializes value data to be persisted to common JSON format
# - Deserializes value data to be retreived from common JSON format
# - Delegates actions to appropriate plugin instance
#
simp_libkv_adapter_class = Class.new do
  require 'base64'
  require 'json'

  attr_accessor :plugin_classes, :plugin_instances

  def initialize
    Puppet.debug 'Constructing anonymous libkv adapter class'
    @plugin_classes   = {} # backend plugin classes;
                           # key = backend type returned by <plugin Class>.type
    @plugin_instances = {} # backend plugin instances;
                           # key = name assigned to the instance, <type>/<id>
                           # supports multiple backend plugin instances per backend

    # Load in the libkv backend plugins from all modules.
    #
    # - Every file in modules/*/lib/puppet_x/libkv/*_plugin.rb is assumed
    #   to contain a libkv backend plugin.
    # - Each plugin file must contain an anonymous class that can be accessed
    #   by a 'plugin_class' local variable.
    # - Each plugin must provide the following methods, which are described
    #   in detail in plugin_api.rb:
    #   - Class methods:
    #     - type: Class method that returns the backend type
    #   - Instance methods:
    #     - initialize: constructor
    #     - name: assigned unique identifier
    #     - delete: delete key from the backend
    #     - deletetree: delete a folder from the backend
    #     - exists: check for existence of key in the backend
    #     - get: retrieve the value of a key in the backend
    #     - list: list the key/value pairs available in a folder in the backend
    #     - put: insert a key/value pair into the backend
    #
    # NOTE: All backend plugins must return a unique value for .type().
    #       Otherwise, only the Class object for last plugin with the same
    #       type will be stored in the plugin_classes Hash.
    #
    modules_dir = File.dirname(File.dirname(File.dirname(File.dirname(File.dirname(__FILE__)))))
    plugin_glob = File.join(modules_dir, '*', 'lib', 'puppet_x', 'libkv', '*_plugin.rb')
    Dir.glob(plugin_glob) do |filename|
      # Load plugin code.  Code evaluated will set this local scope variable
      # 'plugin_class' to the anonymous Class object for the plugin
      # contained in the file.
      # NOTE:  'plugin_class' **must** be defined prior to the eval in order
      #        to be in scope and thus to contain the Class object
      Puppet.debug("Loading libkv plugin from #{filename}")
      begin
        plugin_class = nil
        self.instance_eval(File.read(filename), filename)
        @plugin_classes[plugin_class.type] = plugin_class
      rescue SyntaxError => e
        Puppet.warn("libkv plugin from #{filename} failed to load: #{e.message}"
      end
    end
  end

  ###### Public API ######

  # @return list of backend plugins (i.e. their types) that have successfully
  #   loaded
  def backends
    return plugin_classes.keys
  end

  # execute delete operation on the backend, after normalizing the key
  #
  # @return Empty Hash upon success and a Hash with an error message (:err_msg)
  #   upon failure
  def delete(key, options)
    normalized_key = normalize_key(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
    rescue Exception => e
      result = { :err_msg => e.message }
    end

    if instance
      begin
        result = instance.delete(normalized_key)
      rescue Exception => e
        result = { :err_msg => "libkv #{instance.name} Error: #{e.message}") }
      end
    end

    result
  end

  # execute deletetree operation on the backend
  #
  # @return Empty Hash upon success and a Hash with an error message (:err_msg)
  #   upon failure
  def deletetree(keydir, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
    rescue Exception => e
      result = { :err_msg => e.message }
    end

    if instance
      begin
        result = instance.deletetree(keydir)
      rescue Exception => e
        result = { :err_msg => "libkv #{instance.name} Error: #{e.message}") }
      end
    end

    result
  end

  # execute exists operation on the backend, after normalizing the key
  #
  # @return Hash result with the key presence status (:present) upon
  #   success or an error message (:err_msg) upon failure
  def exists(key, options)
    normalized_key = normalize_key(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
    rescue Exception => e
      result = { :err_msg => e.message }
    end

    if instance
      begin
        result = instance.exists(normalized_key)
      rescue Exception => e
        result = { :err_msg => "libkv #{instance.name} Error: #{e.message}") }
      end
    end

    result
  end

  # execute get operation on the backend, after normalizing the key
  # @return Hash result with the value (:value) and any metadata (:metadata) upon
  #   success or an error message (:err_msg) upon failure
  def get(key, options)
    normalized_key = normalize_key(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
    rescue Exception => e
      result = { :err_msg => e.message }
    end

    if instance
      begin
        raw_result = instance.get(normalized_key)
        if raw_result.has_key?(:value)
          result = deserialize(raw_result[:value])
        else
          result = raw_result
        end
      rescue Exception => e
        result = { :err_msg => "libkv #{instance.name} Error: #{e.message}") }
      end
    end

    result
  end

  def list(params)
    normalized_key = normalize_key(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
    rescue Exception => e
      result = { :err_msg => e.message }
    end

    if instance
      begin
        raw_result = instance.list(normalized_key)
#FIXME Need to deserialize each value
        if raw_result.has_key?(:value)
          result = deserialize(raw_result[:value])
        else
          result = raw_result
        end
      rescue Exception => e
        result = { :err_msg => "libkv #{instance.name} Error: #{e.message}") }
      end
    end

    result
  end

  # execute put operation on the backend, after normalizing the key
  # and serializing the value+metadata
  #
  # @return Empty Hash upon success and a Hash with an error message (:err_msg)
  #   upon failure
  def put(key, value, metadata, options)
    normalized_key = normalize_key(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
    rescue Exception => e
      result = { :err_msg => e.message }
    end

    if instance
      begin
        normalized_value = serialize(value, metadata)
        result = instance.put(normalized_key, normalized_value)
      rescue Exception => e
        result = { :err_msg => "#{instance.name} Error: #{e.message}") }
      end
    end

    result
  end

  ###### Internal methods ######

  # prepend key with environment specified in options Hash
  def normalize_key(key, options)
    env = options.get('environment', '')
    if env.empty?
      return key
    else
      return "#{environment}/#{key}"
    end
  end

  # Creates or retrieves an instance of the backend plugin class specified
  # by the options Hash
  #
  # The options Hash must contain the following:
  # - options['backend'] = the backend configuration to use
  # - options['backends'][ options['backend'] ] = config Hash for the backend
  # - options['backends'][ options['backend'] ]['id'] = backend id; unique
  #   over all backends of the configured type
  # - options['backends'][ options['backend'] ]['type'] = backend type; maps
  #   to one and only one backend plugin, i.e., the backend plugin class whose
  #   type method returns this value
  #
  # The new object will be uniquely identified by a <type>/<id> key.
  #
  # @return an instance of a backend plugin class specified by options
  # @raise if any required backend configuration is missing or the backend
  #   plugin constructor fails
  def plugin_instance(options)
    # backend config should already have been verified, but just in case...
    unless (
        options.is_a?(Hash) &&
        options.has_key?('backend') &&
        options.has_key?('backends') &&
        options['backends'].is_a?(Hash) &&
        options['backends'].has_key?(options['backend']) &&
        options['backends'][ options['backend'] ].has_key?('id') &&
        options['backends'][ options['backend'] ].has_key?('type') &&
        plugin_classes.has_key?(options['backends'][ options['backend'] ]['type'])
    )
      raise("libkv Internal Error: Malformed backend config in options=#{options}")
    end

    backend = options['backend']
    backend_config = options['backends'][backend]
    id = backend_config['id']
    type = backend_config['type']

    name = "#{type}/#{id}"
    unless plugin_instances.has_key?(name)
      begin
        plugin_instances[name] = plugin_classes[backend].new(name, backend_config)
      rescue Exception => e
        msg = "libkv Error: Unable to construct #{name}: #{e.message}"
        raise(msg)
      end
    end
    plugin_instances[name]
  end

  #FIXME This should use Puppet's serialization code so that
  # all contained Binary strings in the value object are properly serialized
  def serialize(value, metadata)
    if value.is_a?(String) && (value.encoding == 'ASCII-8BIT')
      encoded_value = Base64.strict_encode64(value)
      encapsulation = {
        'value' => encoded_value,
        'encoding' => 'base64',
        'original_encoding' => 'ASCII-8BIT',
        'metadata' => metadata
      }
    else
      encapsulation = { 'value' => value, 'metadata' => metadata }
    end
    encapsulation.to_json
  end


  #FIXME This should use Puppet's deserialization code so that
  # all contained Binary strings in the value object are properly deserialized
  def deserialize(serialized_value)
    encapsulation = JSON.parse(serialized_value)
    unless encapsulation.has_key?('value')
      raise("Failed to deserialized: Value missing in '#{serialized_value}'")
    end

    result = {}
    if encapsulation['value'].is_a?(String)
      result[:value] = deserialize_string_value(encapsulation)
    else
      result[:value] = encapsulation['value']
    end

    if encapsulation.has_key?('metadata')
      result[:metadata] =  encapsulation['metadata']
    end
    result
  end

  def deserialize_string_value(encapsulation)
    value = encapsulation['value']
    if encapsulation.has_key?('encoding')
      # right now, only support base64 encoding
      if encapsulation['encoding'] == 'base64'
        value = Base64.strict_decode64(encapsulation['value']
        if encapsulation.has_key?('original_encoding')
          value.force_encoding(encapsulation['original_encoding'])
        end
      else
        raise("Failed to deserialized: Unsupported encoding in '#{encapsulation}'")
      end
    end

    value
  end
end
