# Copy this file to <plugin name>_plugin.rb and address the FIXMEs
#

# DO NOT CHANGE THIS LINE!!!!
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
plugin_class = Class.new do

  # Reminder:  Do **NOT** try to set constants in this Class.new block.
  #            They don't do what you expect (are not accessible within
  #            any class methods) and pollute the Object namespace.

  ###### Public Plugin API ######

  # @return String. backend type
  def self.type
    # This is the value that will be in the 'type' attribute of a configuration
    # block for this plugin.  The libkv adapter uses to select the plugin class to
    # use in order to create a plugin instance.
    # This **MUST** be unique across all loaded plugins.  Only the first
    # plugin of a particular type will be loaded!
    'FIXME'
  end


  # Construct an instance of this plugin using global and plugin-specific
  # configuration found in options
  #
  # FIXME:  The description below is informational for you as a developer.
  # Insert the appropriate description of configuration your plugin
  # supports.
  #
  # The plugin-specific configuration will be found in
  # `options['backends'][ options['backend'] ]`
  #
  # For example,
  # {
  #   # global options
  #   'environment' => 'production',  # <== environment for the node
  #   'softfail'    => false,         # <== for use by libkv Puppet functions
  #
  #   # specific backend config to use
  #   'backend' => 'example_1',      # <== tells you which config to use, i.e.,
  #                                  #     the key in 'backends' Hash       ----
  #                                                                            |
  #   # config for all backend instances                                       |
  #   'backends' => {                                                          |
  #     'default => {           # <== config for an instance of 'file'         |
  #       'type' => 'file',     # <== plugin to use                            |
  #       'id'   => 'config_1', # <== unique instance id                       |
  #       ...                                                                  |
  #     },                                                                     |
  #     ...                                                                    |
  #     'example_1' => {        # <== config for an instance of 'example' <-----
  #       'type' => 'example',  # <== plugin to use
  #       'id'   => 'config_1', # <== unique instance id
  #       'foo'  => 'bar',      # <== config specific to 'example' plugin
  #       ...
  #     },
  #     'example_2' => {        # <== config for another instance of 'example'
  #       'type' => 'example',
  #       'id'   => 'config_2',
  #       'foo'  => 'baz,'
  #       ...
  #     }
  #   }
  #
  # @param name Name to ascribe to this plugin instance
  # @param options Hash of global libkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options
  #   or this object can't set up any stateful objects it needs to do its work
  #   (e.g., file directory, connection to a backend)
  def initialize(name, options)
    # save this off, because the libkv adapter will access it through a getter
    # (defined below) when constructing log messages
    @name = name

    # FIXME: insert validation and set up code here

    Puppet.debug("#{@name} libkv plugin constructed")
  end

  # @return unique identifier assigned to this plugin instance
  def name
    @name
  end


  # The remaining methods in this API map one-for-one to those in
  # libkv's Puppet function API.
  #
  # IMPORTANT NOTES:
  #
  # - An instance of this plugin class will persist through a single catalog run.
  # - Other instances of this plugin class may be running concurrently in
  #   the same process.
  #
  #   * Make sure your code is multi-thread safe if you are using any
  #     mechanisms that would cause concurrency problems!
  #
  # - All values persisted and returned are Strings.  Other software in the
  #   libkv function chain is responsible for serializing non-String
  #   values into Strings for plugins to persist and then deserializing
  #   Strings retrieved by plugins back into objects.
  #
  # - Each of the API methods return a results object that is a Hash
  #   with 2 keys:
  #
  #   * :result - The result of the operation.  Operation specific.
  #   * :err_msg - A String you set to an error message that is meaningful
  #     to the end user, upon failure.
  #
  # - Although the libkv adapter will rescue any exceptions thrown, each of
  #   these methods should do its very best to rescue all exceptions itself,
  #   and then convert the exceptions to a failed status result with a
  #   meaningful error message.
  #
  #         >> Only you have the domain knowledge <<
  #         >> to create useful error messages!   <<
  #
  # - If your plugin connects to an external service, you are strongly
  #   encouraged to build retry logic and timeouts into your backend
  #   operations.

  # Deletes a `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def delete(key)

    # FIXME: insert code that connects to the backend an affects the delete
    # operation
    #
    # - This delete should be done atomically
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => false, :err_msg => 'FIXME: not implemented' }
  end

  # Deletes a whole folder from the configured backend.
  #
  # @param keydir String key folder path
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def deletetree(keydir)

    # FIXME: insert code that connects to the backend an affects the deletetree
    # operation
    #
    # - If supported, this deletetree should be done atomically.  If not,
    #   it can be best-effort.
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => false, :err_msg => 'FIXME: not implemented' }
  end

  # Returns whether the `key` exists in the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether key exists; nil if could not
  #     be determined
  #   * :err_msg - String. Explanatory text when status could not be
  #     determined; nil otherwise.
  #
  def exists(key)

    # FIXME: insert code that connects to the backend an affects the exists
    # operation
    #
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => nil, :err_msg => 'FIXME: not implemented' }
  end

  # Retrieves the value stored at `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - String. Retrieved value for the key; nil if could not
  #     be retrieved
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def get(key)

    # FIXME: insert code that connects to the backend an affects the get
    # operation
    #
    # - If possible, this get should be done atomically
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => nil, :err_msg => 'FIXME: not implemented' }
  end

  # Returns a list of all keys/value pairs in a folder
  #
  # This implementation is best effort.  It will attempt to retrieve the
  # information in a folder and only fail if the folder itself cannot be
  # accessed.  Individual key retrieval failures will be ignored.
  #
  # @return results Hash
  #   * :result - Hash of retrieved key/value pairs; nil if the
  #     retrieval operation failed
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def list(keydir)

    # FIXME: insert code that connects to the backend an affects the list
    # operation
    #
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => nil, :err_msg => 'FIXME: not implemented' }
  end

  # Sets the data at `key` to a `value` in the configured backend.
  #
  # @param key String key
  # @param value String value
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def put(key, value)

    # FIXME: insert code that connects to the backend an affects the put
    # operation
    #
    # - This delete should be done atomically
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => false, :err_msg => 'FIXME: not implemented' }
  end

end
