# @summary libkv adapter
#
# Anonymous class that does the following
# - Loads libkv backend plugins as anonymous classes
#   - Prevents cross-environment Ruby code contamination
#     in the puppetserver
#   - Sadly, makes code more difficult to understand and
#     code sharing tricky
# - Instantiates plugin instances as they are needed
#   - Unique instance per plugin <id:type> requested
# - Normalizes key values
# - Serializes value data to be persisted to common JSON format
# - Deserializes value data to be retreived from common JSON format
# - Delegates actions to appropriate plugin instance
#
simp_libkv_adapter_class = Class.new do
  require 'base64'
  require 'json'

  attr_accessor :classes, :instances

  def initialize
    Puppet.debug 'Constructing anonymous libkv adapter class'
    @classes = {}   # backend plugin classes;
                    # key = backend type returned by <plugin Class>.type
    @instances = {} # backend plugin instances;
                    # key = <configured backend id:configured backend type>
                    # supports multiple backend plugin instances per backend

    # Load in the libkv backend plugins from all modules.
    #
    # - Every file in modules/*/lib/puppet_x/libkv/*_plugin.rb is assumed
    #   to contain a libkv backend plugin.
    # - Each plugin file must contain an anonymous class that can be accessed
    #   by a 'plugin_class' local variable.
    # - Each plugin must provide the following methods:
    #   - Class methods:
    #     - type: Class method that returns the backend type
    #   - Instance methods:
    #     - name: unique identifier <configured backend id:backend type>
    #     - delete: delete key from the backend
    #     - deletetree: delete a folder from the backend
    #     - exists: check for existence of key in the backend
    #     - get: retrieve the value of a key in the backend
    #     - list: list the key/value pairs available in a folder in the backend
    #     - put: insert a key/value pair into the backend
    #
    # NOTE: All backend plugins must return a unique value for .type().
    #       Otherwise, only the Class object for last plugin with the same
    #       type will be stored in the classes Hash.
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
        self.instance_eval File.read(filename), filename
        @classes[plugin_class.type] = plugin_class
      rescue SyntaxError => e
        Puppet.warn("libkv plugin from #{filename} failed to load: #{e.message}"
      end
    end
  end

  ###### Public API ######

  # @return list of backend plugins (i.e. their types) that have successfully
  #   loaded
  def backends
    return classes.keys
  end

  def delete(params)
    instance = provider_instance(params)
  end

  def deletetree(params)
    instance = provider_instance(params)
  end

  def exists(params)
    instance = provider_instance(params)
  end

  def get(params)
    instance = provider_instance(params)
  end

  def list(params)
    instance = provider_instance(params)
  end

  # execute put operation on the backend, after normalizing the key
  # and serializing the value+metadata
  #
  # @return Hash with status of the operation (:success)
  #   and error message (:err_msg) in cases of failure
  def put(key, value, metadata, options)
    normalized_key = normalize_key(key, options)
    result = nil
    begin
      normalized_value = serialize(value, metadata)
      instance = plugin_instance(options)
      result = instance.put(key,normalized_value)
    rescue Exception => e
      result = {
        :success => false,
        :err_msg => "#{instance.name}: #{e.message}")
      }
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
  # The new object will be uniquely identified by a <id:type> key.
  #
  # @return an instance of a backend plugin class specified by options
  # @raise if any required backend configuration is missing
  def plugin_instance(options)
    # backend config should already have been verified, but just in case...
    unless ( options.is_a?(Hash) &&
        options.has_key?('backend') &&
        options.has_key?('backends') &&
        options['backends'].is_a?(Hash) &&
        options['backends'].has_key?(options['backend']) &&
        options['backends'][ options['backend'] ].has_key?('id') &&
        options['backends'][ options['backend'] ].has_key?('type') &&
        classes.has_key?(options['backends'][ options['backend'] ]['type'])
      raise("libkv Internal error: Malformed backend config in options=#{options}")
    end

    backend = options['backend']
    backend_config = options['backends'][backend]
    id = backend_config['id']
    type = backend_config['type']

    instance_id = "#{id}:#{type}"
    unless instances.has_key?(instance_id)
      instances[instance_id] = classes[backend].new(backend_config)
    end
    instances[instance_id]
  end

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


  def deserialize(serialized_value)
    encapsulation = JSON.parse(serialized_value)
    unless encapsulation.has_key?('value')
      raise("Failed to deserialized: Value missing in '#{serialized_value}'")
    end

    result = {}
    if encapsulation['value'].is_a?(String)
      result['value'] = deserialize_string_value(encapsulation)
    else
      result['value'] = encapsulation['value']
    end

    if encapsulation.has_key?('metadata')
      result['metadata'] =  encapsulation['metadata']
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

  def method_missing(symbol, url, auth, *args, &block)
    sanitize_input(symbol, args[0])
    # For safety make a new hash. This doesn't prevent side effects
    # but reduces them somewhat
    params = args[0].dup
    nargs = [ params ]
    # ddb hook for testing.
    # if (params['dd'] == true)
    #   binding.pry
    # end

    # Pre-provider mangling
    unless (params.key?("serialize"))
      params["serialize"] = true
    end
    serialize = params["serialize"]
    if (params.key?("mode") == false or params["mode"] == "" or params["mode"] == nil)
      params["mode"] = 'puppet'
    end

    case symbol
    when :put
      if (serialize == true)
        meta = get_metadata(params, object)
        params["value"] = pack(meta, params["value"])
      end
      retval = object.send(symbol, *nargs, &block);
    when :atomic_put
      if (serialize == true)
        meta = get_metadata(params, object)
        params["value"] = pack(meta, params["value"])
      end
      retval = object.send(symbol, *nargs, &block);
    else
      retval = object.send(symbol, *nargs, &block);
    end


    # Post provider mangling
    case symbol
    when :delete
      delete_metadata(params, object)
      return retval
    when :get
      if (serialize == true and params["key"] !~ /.*\.meta$/)
        metadata = get_metadata(params, object);
        return unpack(metadata,retval)
      else
        return retval
      end
    when :atomic_get
      if (serialize == true and params["key"] !~ /.*\.meta$/)
        metadata = get_metadata(params, object);
        if (retval.key?("value"))
          value = unpack(metadata,retval["value"])
          retval["value"] = value
        end
        return retval
      else
        return retval
      end
    when :list
      filtered_list = {}
      retval.each do |entry, value|
        unless (entry =~ /.*\.meta$/)
          if (serialize == true)
            unless (params['key'] == '/')
              metadata = get_metadata(params.merge({ "key" => "#{params['key']}/#{entry}" }), object)
            else
              metadata = get_metadata(params.merge({ "key" => "/#{entry}" }), object)
            end
            filtered_list[entry] = unpack(metadata, value)
          else
            filtered_list[entry] = value
          end
        end
      end
      return filtered_list
    when :atomic_list
      filtered_list = {}
      retval.each do |entry, value|
        unless (entry =~ /.*\.meta$/)
          if (serialize == true)
            unless (params['key'] == '/')
              metadata = get_metadata(params.merge({ "key" => "#{params['key']}/#{entry}" }), object)
            else
              metadata = get_metadata(params.merge({ "key" => "/#{entry}" }), object)
            end
            value["value"] = unpack(metadata, value["value"])
            filtered_list[entry] = value
          else
            filtered_list[entry] = value
          end
        end
      end
      return filtered_list
    else
      return retval
    end
  end

  def pack(meta, value)
    unless (meta["type"] == "String")
      # JSON objects need to be real objects, or else the parser blows up. So wrap in a hash
      encapsulation = { "value" => value }
      encapsulation.to_json
    else
      value
    end
  end

  def unpack(meta, value)
    retval = value
    case meta["mode"]
    when "puppet"
      unless (meta["type"] == "String")
        case meta["format"]
        when "json"
          unless value == nil
            object = JSON.parse(value)
            retval = object["value"]
          end
        else
          raise "Unknown format: #{meta["format"]}"
        end
      end
    else
      raise "Unknown mode: #{meta["mode"]}"
    end
    return retval
  end
end
