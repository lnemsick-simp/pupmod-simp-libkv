# Copy this file to <your module>/lib/puppet_x/simpkv/<plugin type>_plugin.rb,
# read all the documentation in this file and address the FIXMEs.
#
###############################################################################
# SIMPKV PLUGIN REQUIREMENTS
# - The plugin type derived from the plugin's base filename must be unique
#   over **all** plugins loaded.
#   - The simpkv adapter will only load the first plugin it finds of any given
#     type.
#   - The simpkv adapter will emit a warning when multiple plugin files for the
#     same type are detected.
#
# - The plugin code must implement the API in this template.
#
# - The plugin code must protect from cross-puppet-environment contamination.
#   Different versions of the module containing this plugin may be loaded
#   into the puppetserver at the same time. So, unlike normal Ruby library
#   code for which only one version will be loaded at a time (e.g., gems
#   installed in the puppetserver), you have to explicitly design this plugin
#   code to prevent cross-environment-contamination.  This is why the plugin
#   architecture requires this class to be anonymous and loads it appropriately.
#   You must provide similar protections for any supporting Ruby code that you
#   package in the module (e.g., a separate connector class).
#
# - The plugin code must allow multiple instances to be instantiated and run
#   concurrently.
#
# - The plugin code is responsible for executing any appropriate retry logic
#   on failed backend operations.
#
# - The plugin code must protect itself from hung operations.
#
# - When accessing the backend in the put(), get(), ... methods, the plugin code
#   should catch exceptions, convert them to meaningful error messages and then
#   return the failed status in its public API.
###############################################################################


# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
# DO NOT CHANGE THE LINE BELOW!!!!
plugin_class = Class.new do

  # WARNING:
  # In typical Ruby code, using constants and class methods is quite normal.
  # Unfortunately, you cannot use constants or class methods in an anonymous
  # class, as they will be added to the Class Object, itself, and will not be
  # available to the anonymous class. In other words, you will be tearing your
  # hair out trying to figure out why normal Ruby code does not work here!

  ###### Public Plugin API ######

  # Construct an instance of this plugin setting its instance name
  #
  # @param name Name to ascribe to this plugin instance
  #
  def initialize(name)
    # save this off, because the simpkv adapter will access it through a getter
    # (defined below), when constructing log messages
    @name = name

    # You can use the Puppet object for logging
    Puppet.debug("#{@name} simpkv plugin constructed")
  end

  # Configure this plugin instance using global and plugin-specific
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
  #   'softfail'    => false,         # <== for use by simpkv Puppet functions
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
  # @param options Hash of global simpkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options
  #   or this object can't set up any stateful objects it needs to do its work
  #   (e.g., file directory, connection to a backend)
  def configure(options)

    # FIXME: insert validation and set up code here
    # Be sure to create 'globals' and 'environments' sub-folders off of the
    # root directory.

    Puppet.debug("#{@name} simpkv plugin configured")
  end

  # @return unique identifier assigned to this plugin instance
  def name
    @name
  end

  # The remaining methods in this API map one-for-one to those in
  # simpkv's Puppet function API.
  #
  # IMPORTANT API NOTES:
  #
  # - An instance of this plugin class will persist through a single catalog
  #   run.
  # - Other instances of this plugin class may be running concurrently in
  #   the same process.
  #
  #   * Make sure your code is multi-thread safe if you are using any
  #     mechanisms that would cause concurrency problems!
  #
  # - All key values persisted and returned are Strings.  Other software in
  #   the simpkv function chain is responsible for serializing non-String
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
  # - Although the simpkv adapter will rescue any exceptions thrown, each of
  #   these methods should do its very best to rescue all exceptions itself,
  #   and then convert the exceptions to a failed status result with a
  #   meaningful error message.
  #
  #         >> Only you have the domain knowledge <<
  #         >> to create useful error messages!   <<
  #
  # - If your plugin connects to an external service, you are strongly
  #   encouraged to build timeouts and retry logic into your backend
  #   operations.
  #
  #   * The simpkv adapter does not currently protect against hung operations.
  #   * Only you have domain knowledge to know when a connection is hung
  #     and when a retry of a failed operaton is appropriate.

  # Deletes a `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def delete(key)

    # FIXME: insert code that connects to the backend and affects the delete
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

    # FIXME: insert code that connects to the backend and affects the deletetree
    # operation
    #
    # - If supported, this deletetree should be done atomically.  If not,
    #   it can be best-effort.
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => false, :err_msg => 'FIXME: not implemented' }
  end

  # Returns whether key or key folder exists in the configured backend.
  #
  # @param key String key or key folder to check
  #
  # @return results Hash
  #   * :result - Boolean indicating whether key/key folder exists;
  #     nil if could not be determined
  #   * :err_msg - String. Explanatory text when status could not be
  #     determined; nil otherwise.
  #
  def exists(key)

    # FIXME: insert code that connects to the backend and affects the exists
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

    # FIXME: insert code that connects to the backend and affects the get
    # operation
    #
    # - If possible, this get should be done atomically
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => nil, :err_msg => 'FIXME: not implemented' }
  end

  # Returns a listing of all keys/info pairs and sub-folders in a folder
  #
  # The list operation does not recurse through any sub-folders. Only
  # information about the specified key folder is returned.
  #
  # This implementation is best effort.  It will attempt to retrieve the
  # information in a folder and only fail if the folder itself cannot be
  # accessed.  Individual key retrieval failures will be ignored.
  #
  # @return results Hash
  #   * :result - Hash of retrieved key and sub-folder info; nil if the
  #     retrieval operation failed
  #
  #     * :keys - Hash of the key/value pairs for keys in the folder
  #     * :folders - Array of sub-folder names
  #
  #   * :result - Hash of retrieved key/value pairs; nil if the
  #     retrieval operation failed
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def list(keydir)

    # FIXME: insert code that connects to the backend and affects the list
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

    # FIXME: insert code that connects to the backend and affects the put
    # operation
    #
    # - This delete should be done atomically
    # - Convert any exceptions into a failed status result with a meaningful
    #   error message.
    #

    { :result => false, :err_msg => 'FIXME: not implemented' }
  end

end
