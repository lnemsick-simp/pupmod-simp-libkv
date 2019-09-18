# Plugin and store implementation of a file key/value store that resides
# on a local filesystem
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable, which **MUST** be defined the
# loading classes scope
plugin_class = Class.new do

  require 'fileutils'
  require 'timeout'

  # Reminder:  Do NOT try to set constants in this Class.new block.
  #            They don't do what you expect (are not accessible within
  #            any class methods) and pollute the Object namespace.

  ###### Public Plugin API ######

  # @return backend type
  def self.type
    'file'
  end

  # construct an instance of this plugin using global and plugin-specific
  # configuration found in options
  #
  # The plugin-specific configuration will be found in
  # `options['backends'][ options['backend'] ]`:
  #
  # *  `root_path`: root directory path; defaults to '/var/simp/libkv/file'
  # *  `lock_timeout_seconds`: max seconds to wait for an exclusive file lock
  #     on a file modifying operation before failing the operation; defaults
  #     to 20 seconds
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
      @root_path = '/var/simp/libkv/file'
    end

    if options['backends'][backend].has_key?('lock_timeout_seconds')
      @lock_timeout_seconds = options['backends'][backend]['lock_timeout_seconds']
    else
      @lock_timeout_seconds = 5
    end

    unless Dir.exist?(@root_path)
      begin
        FileUtils.mkdir_p(@root_path)
      rescue Exception => e
        raise("libkv plugin #{name} Error: Unable to create #{@root_path}: #{e.message}")
      end
    end

    # make sure the root directory is protected
    begin
      FileUtils.chmod(0750, @root_path)
    rescue Exception => e
      raise("libkv plugin #{name} Error: Unable to set permissions on #{@root_path}: #{e.message}")
    end

    Puppet.debug("#{@name} libkv plugin for #{@root_path} constructed")
  end


  # Deletes a `key` from the configured backend.
  #
  # @return Empty Hash upon success and a Hash with an error message (:err_msg)
  #   upon failure
  def delete(key)
    result = nil
    key_file = File.join(@root_path, key)
    begin
      File.unlink(key_file)
      result = {}
    rescue Errno::ENOENT
      # if the key doesn't exist, doesn't need to be deleted...going
      # to consider this success
      result = {}
    rescue Exception => e
      result = { :err_msg => "Delete failed: #{e.message}" }
    end

    result
  end

  # Deletes a whole folder from the configured backend.
  #
  # @return Empty Hash upon success and a Hash with an error message (:err_msg)
  #   upon failure
  def deletetree(keydir)
    result = nil
    dir = File.join(@root_path, keydir)
    # FIXME:  Is there an atomic way of doing this?
    if Dir.exist?(dir)
      begin
        FileUtils.rm_r(dir)
        result = {}
      rescue Exception => e
        if Dir.exist?(dir)
          result = { :err_msg => "Folder delete failed: #{e.message}" }
        else
          # in case another process/thread successfully deleted the directory
          result = {}
        end
      end
    else
      # if the directory doesn't exist, doesn't need to be deleted...going
      # to consider this success
      result = {}
    end

    result
  end

  # Returns whether the `key` exists in the configured backend.
  #
  # @return Hash result with the key presence status (:present) upon success
  #   or an error message (:err_msg) upon failure
  def exists(key)
    key_file = File.join(@root_path, key)
    # this simple plugin doesn't have any error cases to report with :err_msg
    { :present => File.exist?(key_file) }
  end

  # Retrieves the value stored at `key` from the configured backend.
  #
  # @return Hash result with the value (:value) upon success or an error message
  # (:err_msg) upon failure
  def get(key)
    result = nil
    key_file = File.join(@root_path, key)
    begin
      Timeout::timeout(@lock_timeout_seconds) do
        File.open(key_file, 'r') do |file|
          file.flock(File::LOCK_EX)
          value = file.read
        end
      end
    # Don't need to specify the key in the error messages below, as the key
    # will be appended to the message by the originating libkv::get()
    rescue Errno::ENOENT
      result = { :err_msg => "libkv plugin #{@name}: Key not found"  }
    rescue Timeout::Error
      result = { :err_msg => "libkv plugin #{@name}: Timed out waiting for key file lock"  }
    rescue Exception => e
      result = { :err_msg => "Key retrieval failed: #{e.message}" }
    end
  end

  # Returns a list of all keys in a folder.
  #
  # @return FIXME Hash result with the value (:value) upon success or an error message
  # (:err_msg) upon failure
  def list(keydir)
    result = nil
    if Dir.exist?(File.join(@root_path, keydir))
    else
      # Don't need to specify the key folder in the error message, as the key
      # folder will be reported in the error message generated by the
      # originating libkv::list()
       { :err_msg => "libkv plugin #{@name}: Key folder not found"  }
    end

    result
  end

  # @return unique identifier assigned to this plugin instance
  def name
    @name
  end

  # @return Empty Hash upon success and a Hash with an error message (:err_msg)
  #   upon failure
  def put(key, value)
    result = nil
    key_file = File.join(@root_path, key)
    begin
      Timeout::timeout(@lock_timeout_seconds) do
        # Don't use 'w' as it truncates file before the lock is obtained
        File.open("counter", File::RDWR|File::CREAT, 0640) do |file|
          file.flock(File::LOCK_EX)
          file.rewind
          file.write(value)
          file.flush
          file.truncate(file.pos)
        end
      end
    # Don't need to specify the key in the error messages below, as the key
    # will be appended to the message by the originating libkv::get()
    rescue Timeout::Error
      result = { :err_msg => "libkv plugin #{@name}: Timed out waiting for key file lock"  }
    rescue Exception => e
      result = { :err_msg => "Key write failed: #{e.message}" }
    end

    result
  end

  ###### Internal Methods ######

end
