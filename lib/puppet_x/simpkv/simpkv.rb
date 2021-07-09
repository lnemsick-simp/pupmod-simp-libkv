# @summary simpkv adapter
#
# Anonymous class that does the following
# - Loads simpkv backend plugins as anonymous classes
#   - Prevents cross-environment Ruby code contamination
#     in the puppetserver
#   - Sadly, makes code more difficult to understand and
#     code sharing tricky
# - Instantiates plugin instances as they are needed
#   - Unique instance per plugin {id,type} pair requested
# - Normalizes key values
# - Serializes value data to be persisted to common JSON format
# - Deserializes value data to be retrieved from common JSON format
# - Delegates actions to appropriate plugin instance
#
simp_simpkv_adapter_class = Class.new do
  require 'base64'
  require 'json'
  require 'pathname'

  attr_accessor :plugin_info, :plugin_instances

  def initialize
    Puppet.debug('Constructing simpkv adapter from anonymous class')
    @plugin_info   = {}    # backend plugin classes;
                           # key = backend type derived from the plugin base
                           #       filename (<plugin type>_plugin.rb)
                           # value = { :class  => <loaded class obj>,
                           #           :source => <plugin file path>
                           #         }
    @plugin_instances = {} # backend plugin instances;
                           # key = name assigned to the instance, <type>/<id>
                           # supports multiple backend plugin instances per backend

    # Load in the simpkv backend plugins from all modules.
    #
    # - Every file in modules/*/lib/puppet_x/simpkv/*_plugin.rb is assumed
    #   to contain a simpkv backend plugin.
    # - A field in the base filename of the plugin defines the plugin type,
    #   <plugin type>_.plugin.rb, and only the first plugin found for a
    #   type will be loaded.
    # - Each plugin file must contain an anonymous class that can be accessed
    #   by a 'plugin_class' local variable.
    # - Each plugin must provide the following instance methods, which are
    #   described in detail in plugin_template.rb:
    #   - initialize: constructor
    #   - configure: Configure the plugin instance
    #   - name: return unique identifier assigned to the plugin instance
    #   - delete: delete key from the backend
    #   - deletetree: delete a folder from the backend
    #    - exists: check for existence of key in the backend
    #   - get: retrieve the value of a key in the backend
    #   - list: list the key/value pairs and sub-folders available in a
    #     folder in the backend
    #   - put: insert a key/value pair into the backend
    #
    modules_dir = File.dirname(File.dirname(File.dirname(File.dirname(File.dirname(__FILE__)))))
    plugin_glob = File.join(modules_dir, '*', 'lib', 'puppet_x', 'simpkv', '*_plugin.rb')
    Dir.glob(plugin_glob).sort.each do |filename|
      # Load plugin code.  Code evaluated will set this local scope variable
      # 'plugin_class' to the anonymous Class object for the plugin
      # contained in the file.
      # NOTE:  'plugin_class' **must** be defined prior to the eval in order
      #        to be in scope and thus to contain the Class object
      Puppet.debug("Loading simpkv plugin from #{filename}")
      begin
        plugin_class = nil
        self.instance_eval(File.read(filename), filename)
        plugin_type = File.basename(filename, '_plugin.rb')
        if @plugin_info.has_key?(plugin_type)
          msg = "Skipping load of simpkv plugin from #{filename}: " +
            "plugin type '#{plugin_type}' already loaded from " +
            @plugin_info[plugin_type][:source]
          Puppet.warning(msg)
        else
          @plugin_info[plugin_type] = {
            :class  => plugin_class,
            :source => filename
          }
        end
      rescue SyntaxError => e
        Puppet.warning("simpkv plugin from #{filename} failed to load: #{e.message}")
      end
    end
  end

  ###### Public API ######

  # @return list of backend plugins (i.e. their types) that have successfully
  #   loaded
  def backends
    return plugin_info.keys.sort
  end

  # execute delete operation on the backend, after normalizing the key
  #
  # @param key String key
  # @param options Hash of global simpkv and backend-specific options
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def delete(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
      result = instance.delete( normalize_key(key, options) )
    rescue Exception => e
      bt = filter_backtrace(e.backtrace)
      prefix = instance.nil? ? 'simpkv' : "simpkv #{instance.name}"
      err_msg = "#{prefix} Error: #{e.message}\n#{bt.join("\n")}".strip
      result = { :result => false, :err_msg => err_msg }
    end

    result
  end

  # execute deletetree operation on the backend, after normalizing the
  # folder name
  #
  # @param keydir String key folder path
  # @param options Hash of global simpkv and backend-specific options
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def deletetree(keydir, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
      result = instance.deletetree( normalize_key(keydir, options) )
    rescue Exception => e
      bt = filter_backtrace(e.backtrace)
      prefix = instance.nil? ? 'simpkv' : "simpkv #{instance.name}"
      err_msg = "#{prefix} Error: #{e.message}\n#{bt.join("\n")}".strip
      result = { :result => false, :err_msg => err_msg }
    end

    result
  end

  # execute exists operation on the backend, after normalizing the key
  #
  # @param key String key or key folder to check
  # @param options Hash of global simpkv and backend-specific options
  #
  # @return results Hash
  #   * :result - Boolean indicating whether key/key folder exists;
  #     nil if could not be determined
  #   * :err_msg - String. Explanatory text when status could not be
  #     determined; nil otherwise.
  #
  def exists(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
      result = instance.exists( normalize_key(key, options) )
    rescue Exception => e
      bt = filter_backtrace(e.backtrace)
      prefix = instance.nil? ? 'simpkv' : "simpkv #{instance.name}"
      err_msg = "#{prefix} Error: #{e.message}\n#{bt.join("\n")}".strip
      result = { :result => nil, :err_msg => err_msg }
    end

    result
  end

  # execute get operation on the backend, after normalizing the key
  #
  # @param key String key
  # @param options Hash of global simpkv and backend-specific options
  #
  # @return results Hash
  #   * :result - Hash containing :value and :metadata keys; nil if could not
  #     be retrieved
  #     * :value = Retrieved value for the key
  #     * :metadata = Retrieved metadata Hash for the key
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def get(key, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
      raw_result = instance.get( normalize_key(key, options) )
      if raw_result[:result]
        value = deserialize(raw_result[:result])
        result = { :result => value, :err_msg => nil }
      else
        result = raw_result
      end
    rescue Exception => e
      bt = filter_backtrace(e.backtrace)
      prefix = instance.nil? ? 'simpkv' : "simpkv #{instance.name}"
      err_msg = "#{prefix} Error: #{e.message}\n#{bt.join("\n")}".strip
      result = { :result => nil, :err_msg => err_msg }
    end

    result
  end

  # Returns a listing of all keys/info pairs and all sub-folders in a folder,
  # after normalizing the folder name
  #
  # The list operation does not recurse through any sub-folders. Only
  # information about the specified key folder is returned.
  #
  # @param keydir String key folder path
  # @param options Hash of global simpkv and backend-specific options
  #
  # @return results Hash
  #   * :result - Hash of retrieved key and sub-folder info; nil if the
  #     retrieval operation failed
  #
  #     * :keys - Hash of the key information in the folder
  #       * Each Hash key is a key found in the folder
  #       * Each Hash value is a Hash with :value and :metadata keys.
  #     * :folders - Array of sub-folder names
  #
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def list(keydir, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
      raw_result = instance.list( normalize_key(keydir, options) )
      if raw_result[:result]
       result = {
          :result  => { :keys => {}, :folders => [] },
          :err_msg => nil
        }

        raw_result[:result][:folders].each do |raw_folder|
          folder = normalize_key(raw_folder, options, :remove_prefix)
          result[:result][:folders] << folder
        end

        raw_result[:result][:keys].each do |raw_key,raw_value|
          key = normalize_key(raw_key, options, :remove_prefix)
          result[:result][:keys][key] = deserialize(raw_value)
        end
      else
        result = raw_result
      end
    rescue Exception => e
      bt = filter_backtrace(e.backtrace)
      prefix = instance.nil? ? 'simpkv' : "simpkv #{instance.name}"
      err_msg = "#{prefix} Error: #{e.message}\n#{bt.join("\n")}".strip
      result = { :result => nil, :err_msg => err_msg }
    end

    result
  end

  # execute put operation on the backend, after normalizing the key
  # and serializing the value+metadata
  #
  # @param key String key
  # @param options Hash of global simpkv and backend-specific options
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  def put(key, value, metadata, options)
    instance = nil
    result = nil
    begin
      instance = plugin_instance(options)
      normalized_key = normalize_key(key, options)
      normalized_value = serialize(value, metadata)
      result = instance.put(normalized_key, normalized_value)
    rescue Exception => e
      bt = filter_backtrace(e.backtrace)
      prefix = instance.nil? ? 'simpkv' : "simpkv #{instance.name}"
      err_msg = "#{prefix} Error: #{e.message}\n#{bt.join("\n")}".strip
      result = { :result => false, :err_msg => err_msg }
    end

    result
  end

  ###### Internal methods ######
  #
  # @return prefix to be used in the path for global keys/folders
  def environment_prefix(environment)
    "environments/#{environment}"
  end

  # @return Skinnied down exception backtrace for more useful reporting of
  #   errors. This is especially helpful when debugging plugin code!
  #
  # @param backtrace Full exception backtrace
  #
  def filter_backtrace(backtrace)
    # Only go up to last line with a simpkv function file path. This removes
    # all the useless, subsequent lines for the Puppet library internals.
    # The user will still know the manifest that couldn't be compiled,
    # because the compiler automatically adds a log line that reports the
    # manifest file and line number that failed compilation.
    short_bt = backtrace.reverse.drop_while { |line|
      !line.include?('/simpkv/lib/puppet/functions/simpkv/')
    }
    short_bt.reverse
  end

  # @return prefix to be used in the path for global keys/folders
  def global_prefix
    'globals'
  end

  # Adjust the key per the 'environment' and 'global' settings
  # in the options Hash
  #
  # @param key Key string to be normalized
  # @param options Options hash that may specify 'global'
  # @param operation Normalize operation
  #   * :add_prefix - Add the appropriate environment/global prefix
  #     to the key
  #   * :remove_prefix - Remove the appropriate environment/global prefix
  #     from the key
  #
  # @return normalized key
  #
  def normalize_key(key, options, operation = :add_prefix)
    normalized_key = key.dup
    if options.fetch('global', false)
      prefix = global_prefix
    else
      prefix = environment_prefix(options['environment'])
    end

    case operation
    when :add_prefix
      normalized_key = "#{prefix}/#{key}"
    when :remove_prefix
      normalized_key = key.gsub(/^#{prefix}\//,'')
    else
      # do nothing
    end

    # get rid of extraneous slashes
    Pathname.new(normalized_key).cleanpath.to_s
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
        plugin_info.has_key?(options['backends'][ options['backend'] ]['type'])
    )
      raise("Malformed backend config in options=#{options}")
    end

    backend = options['backend']
    backend_config = options['backends'][backend]
    id = backend_config['id']
    type = backend_config['type']

    name = "#{type}/#{id}"
    unless plugin_instances.has_key?(name)
      begin
        plugin_instances[name] = plugin_info[type][:class].new(name)
        plugin_instances[name].configure(options)
      rescue Exception => e
        raise("Unable to construct '#{name}': #{e.message}")
      end
    end
    plugin_instances[name]
  end

  # Deserializes JSON to a Hash containing :value and :metadata keys
  #
  # See limitations of #serialize() below
  #
  # @return Hash containing :value and :metadata keys
  # @raise RuntimeError if the serialized_value does not contain valid JSON,
  #   if the Hash representation of serialized_value does not contain a 'value'
  #   key, or the optional 'encoding' key contains an unsupported encoding
  #   scheme.
  #
  #FIXME This should use Puppet's deserialization code so that
  # all contained Binary strings in the value object are properly deserialized
  def deserialize(serialized_value)
    begin
      encapsulation = JSON.parse(serialized_value)
    rescue JSON::ParserError => e
      raise("Failed to deserialize: JSON parse error: #{e}")
    end
    unless encapsulation.has_key?('value')
      raise("Failed to deserialize: 'value' missing in '#{serialized_value}'")
    end

    result = {}
    if encapsulation['value'].is_a?(String)
      result[:value] = deserialize_string_value(encapsulation)
    else
      result[:value] = encapsulation['value']
    end

    result[:metadata] = encapsulation['metadata']

    result
  end

  # @raise RuntimeError if the optional 'encoding' specifie dis not 'base64'
  def deserialize_string_value(encapsulation)
    value = encapsulation['value']
    if encapsulation.has_key?('encoding')
      # right now, only support base64 encoding
      if encapsulation['encoding'] == 'base64'
        value = Base64.strict_decode64(encapsulation['value'])
        if encapsulation.has_key?('original_encoding')
          value.force_encoding(encapsulation['original_encoding'])
        end
      else
        raise("Failed to deserialize: Unsupported encoding in '#{encapsulation}'")
      end
    end

    value
  end

  # Serializes objects to JSON
  #
  # @param value The value for a key
  # @param metadata The metadata Hash for the key
  #
  # @return JSON representation of the value and metadata
  # @raise If object cannot be serialized to JSON
  #
  # This is a **LIMITED** implementation meant for prototyping the simpkv API.
  # *  It can only handle objects that have a meaningful to_json method.
  #    Ruby primitives (String, Integer, Float, Boolean) and Arrays and Hashes
  #    containing them are OK. Custom classes that use the default Object to_json
  #    (i.e., the one that simply prints out the class name and object ID such as
  #    "#<MyTest:0x0000000000e9b6f0>") will not be OK.
  # *  It can only handle binary String data in the value when the value is a
  #    String object.  All other cases (e.g., binary Strings within a Hash or
  #    Array value, binary Strings within the metadata Hash) will fail
  #    serialization unless that binary data just happens to form valid UTF-8.
  #
  #FIXME This should use Puppet's serialization code so that all contained Binary
  # strings are properly serialized
  def serialize(value, metadata)
    encapsulation = nil
    if value.is_a?(String)
      encapsulation = serialize_string_value(value, metadata)
    elsif value.respond_to?(:binary_buffer)
      # This is a Puppet Binary type
      encapsulation = serialize_binary_data(value.binary_buffer, metadata)
    else
      encapsulation = { 'value' => value, 'metadata' => metadata }
    end
    # This will raise an error if the value or metadata contains
    # any element that cannot be serialized to JSON.  Caller catches
    # error and reports failure.
    encapsulation.to_json
  end

  def serialize_binary_data(value, metadata)
    encoded_value = Base64.strict_encode64(value)
    encapsulation = {
      'value'             =>  encoded_value,
      'encoding'          => 'base64',
      'original_encoding' => 'ASCII-8BIT',
      'metadata'          => metadata
    }
  end

  def serialize_string_value(value, metadata)
    normalized_value = value.dup
    if (normalized_value.encoding == Encoding::UTF_8) &&
       !normalized_value.valid_encoding?
      # this was a user error...on decoding, the encoding error will be fixed
      # TODO Should we fail instead and tell the user to use a Binary type?
      normalized_value.force_encoding('ASCII-8BIT')
    end

    encapsulation = nil
    if normalized_value.encoding == Encoding::ASCII_8BIT
      encapsulation = serialize_binary_data(normalized_value, metadata)
    else
      encapsulation = { 'value' => normalized_value, 'metadata' => metadata }
    end
    encapsulation
  end

end
