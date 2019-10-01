# Plugin and store implementation of a file key/value store that resides
# on a local filesystem
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
plugin_class = Class.new do

  require 'fileutils'
  require 'timeout'

  # Reminder:  Do **NOT** try to set constants in this Class.new block.
  #            They don't do what you expect (are not accessible within
  #            any class methods) and pollute the Object namespace.

  ###### Public Plugin API ######

  # @return String. backend type
  def self.type
    'file'
  end

  # construct an instance of this plugin using global and plugin-specific
  # configuration found in options
  #
  # The plugin-specific configuration will be found in
  # `options['backends'][ options['backend'] ]`:
  #
  # * `root_path`: root directory path; defaults to '/var/simp/libkv/<name>'
  # * `lock_timeout_seconds`: max seconds to wait for an exclusive file lock
  #   on a file modifying operation before failing the operation; defaults
  #   to 5 seconds
  # * `user`: user for created directories and files; defaults to user
  #   executing code
  # * `group`: group for created directories and files; defaults to group
  #   executing code
  #
  # @param name Name to ascribe to this plugin instance
  # @param options Hash of global libkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options,
  #   the root directory cannot be created when missing, the permissions of the
  #   root directory cannot be set
  def initialize(name, options)
    # backend config should already have been verified, but just in case...
    unless (
        options.is_a?(Hash) &&
        options.has_key?('backend') &&
        options.has_key?('backends') &&
        options['backends'].is_a?(Hash) &&
        options['backends'].has_key?(options['backend']) &&
        options['backends'][ options['backend'] ].has_key?('id') &&
        options['backends'][ options['backend'] ].has_key?('type') &&
        # self is not available to an anonymous class and can't use constants,
        # so have to repeat what is already in self.type
        (options['backends'][ options['backend'] ]['type'] == 'file')
    )
      raise("libkv plugin #{name} misconfigured: #{options}")
    end

    @name = name

    # set optional configuration
    backend = options['backend']
    if options['backends'][backend].has_key?('root_path')
      @root_path = options['backends'][backend]['root_path']
    else
      @root_path = File.join('/', 'var', 'simp', 'libkv', name)
    end

    if options['backends'][backend].has_key?('lock_timeout_seconds')
      @lock_timeout_seconds = options['backends'][backend]['lock_timeout_seconds']
    else
      @lock_timeout_seconds = 5
    end

    @user = options['backends'][backend].fetch('user', nil)
    @group = options['backends'][backend].fetch('group', nil)

    unless Dir.exist?(@root_path)
      begin
        FileUtils.mkdir_p(@root_path)
      rescue Exception => e
        raise("libkv plugin #{name} Error: Unable to create #{@root_path}: #{e.message}")
      end
    end

    # set permissions on the root directory
    begin
      FileUtils.chmod(0750, @root_path)
      FileUtils.chown(@user, @group, @root_path) if @user || @group
    rescue Exception => e
      raise("libkv plugin #{name} Error: Unable to set permissions on #{@root_path}: #{e.message}")
    end

    Puppet.debug("#{@name} libkv plugin for #{@root_path} constructed")
  end


  # Deletes a `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def delete(key)
    success = nil
    err_msg = nil
    key_file = File.join(@root_path, key)
    if File.directory?(key_file)
      success = false
      err_msg = "libkv plugin #{@name}: Key specifies a folder"
    else
      begin
        File.unlink(key_file)
        success = true
      rescue Errno::ENOENT
        # if the key doesn't exist, doesn't need to be deleted...going
        # to consider this success
        success = true
      rescue Exception => e
        success = false
        err_msg = "Delete failed: #{e.message}"
      end
    end

    { :result => success, :err_msg => err_msg }
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
    success = nil
    err_msg = nil
    dir = File.join(@root_path, keydir)
    # FIXME:  Is there an atomic way of doing this?
    if Dir.exist?(dir)
      begin
        FileUtils.rm_r(dir)
        success = true
      rescue Exception => e
        if Dir.exist?(dir)
          success = false
          err_msg = "Folder delete failed: #{e.message}"
        else
          # in case another process/thread successfully deleted the directory
          success = true
        end
      end
    else
      # if the directory doesn't exist, doesn't need to be deleted...going
      # to consider this success
      success = true
    end

    { :result => success, :err_msg => err_msg }
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
    key_file = File.join(@root_path, key)
    # this simple plugin doesn't have any error cases that would be reported
    # in :err_msg
    { :result => File.exist?(key_file), :err_msg => nil }
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
    value = nil
    err_msg = nil
    key_file = File.join(@root_path, key)
    if File.directory?(key_file)
      err_msg = "libkv plugin #{@name}: Key specifies a folder"
    else
      begin
        Timeout::timeout(@lock_timeout_seconds) do
          # To ensure all threads are not sharing the same file descriptor
          # do **NOT** use a File.open block!
          file = File.open(key_file, 'r')
          file.flock(File::LOCK_EX)
          value = file.read
          file.close # lock released with close
        end

      # Don't need to specify the key in the error messages below, as the key
      # will be appended to the message by the originating libkv::get()
      rescue Errno::ENOENT
        err_msg = "libkv plugin #{@name}: Key not found"
      rescue Timeout::Error
        err_msg = "libkv plugin #{@name}: Timed out waiting for key file lock"
      rescue Exception => e
        err_msg = "Key retrieval failed: #{e.message}"
      end
    end
    { :result => value, :err_msg => err_msg }
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
    pairs = nil
    err_msg = nil
    dir = File.join(@root_path, keydir)
    if Dir.exist?(dir)
      pairs = {}
      Dir.glob(File.join(dir,'*')).each do |keyfile|
        key = keyfile.gsub(@root_path + File::SEPARATOR,'')
        result = get(key)
        unless result[:result].nil?
          pairs[key] = result[:result]
        end
      end
    else
      # Don't need to specify the key folder in the error message, as the key
      # folder will be reported in the error message generated by the
      # originating libkv::list()
       err_msg = "libkv plugin #{@name}: Key folder not found"
    end

    { :result => pairs, :err_msg => err_msg }
  end

  # @return unique identifier assigned to this plugin instance
  def name
    @name
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
    success = nil
    err_msg = nil

    begin
      # create relative directory for the key file
      keydir = File.dirname(key)
      unless keydir == '.'
        Dir.chdir(@root_path) do
          FileUtils.mkdir_p(keydir, :mode => 0750)
          FileUtils.chown_R(@user, @group, keydir) if @user || @group
        end
      end

      # create key file
      key_file = File.join(@root_path, key)
      Timeout::timeout(@lock_timeout_seconds) do
        # To ensure all threads are not sharing the same file descriptor
        # do **NOT** use a File.open block!
        # Also, don't use 'w' as it truncates file before the lock is obtained
        file = File.open(key_file, File::RDWR|File::CREAT, 0640)
        file.flock(File::LOCK_EX)
        file.rewind
        file.write(value)
        file.flush
        file.truncate(file.pos)
        file.close # lock released with close
      end
      FileUtils.chown(@user, @group, key_file) if @user || @group
      success = true

    # Don't need to specify the key in the error messages below, as the key
    # will be appended to the message by the originating libkv::get()
    rescue Timeout::Error
      success = false
      err_msg = "libkv plugin #{@name}: Timed out waiting for key file lock"
    rescue Exception => e
      success = false
      err_msg = "Key write failed: #{e.message}"
    end

    { :result => success, :err_msg => err_msg }
  end

  ###### Internal Methods ######

end
