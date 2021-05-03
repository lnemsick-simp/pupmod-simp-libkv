# Plugin and store implementation of a file key/value store that resides
# on a local filesystem
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
# DO NOT CHANGE THE LINE BELOW!!!!
plugin_class = Class.new do

  require 'etc'
  require 'fileutils'
  require 'timeout'

  # NOTES FOR MAINTAINERS:
  # - See simpkv/lib/puppet_x/simpkv/plugin_template.rb for important
  #   information about plugin responsibilties and restrictions.
  # - One OBTW that will drive you crazy are limitations on anonymous classes.
  #   In typical Ruby code, using constants and class methods is quite normal.
  #   Unfortunately, you cannot use constants or class methods in an anonymous
  #   class, as they will be added to the Class Object, itself, and will not be
  #   available to the anonymous class. In other words, you will be tearing your
  #   hair out trying to figure out why normal Ruby code does not work here!

  ###### Public Plugin API ######

  # Construct an instance of this plugin setting its instance name
  #
  # @param name Name to ascribe to this plugin instance
  #
  def initialize(name)
    @name = name
    Puppet.debug("#{@name} simpkv plugin configured")
  end

  # Configure this plugin instance using global and plugin-specific
  # configuration found in options
  #
  # The plugin-specific configuration will be found in
  # `options['backends'][ options['backend'] ]`:
  #
  # * `root_path`: root directory path; defaults to '/var/simp/simpkv/<name>' when
  #     that directory can be created or '<Puppet[:vardir]>/simp/simpkv/<name>'
  #     otherwise
  # * `lock_timeout_seconds`: max seconds to wait for an exclusive file lock
  #   on a file modifying operation before failing the operation; defaults
  #   to 5 seconds
  #
  # @param options Hash of global simpkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options,
  #   the root directory can be created when missing, or the root directory
  #   exists but cannnot be read/modified by this process
  def configure(options)
    # backend config should already have been verified by simpkv adapter, but
    # just in case...
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
      raise("Plugin misconfigured: #{options}")
    end


    # set optional configuration
    backend = options['backend']
    @root_path = ensure_root_path(options)
    if options['backends'][backend].has_key?('lock_timeout_seconds')
      @lock_timeout_seconds = options['backends'][backend]['lock_timeout_seconds']
    else
      @lock_timeout_seconds = 5
      Puppet.debug("simpkv plugin #{name}: Using default lock timeout #{@lock_timeout_seconds}")
    end

    # create parent directories for global and Puppet environment keys
    ensure_folder_path('globals')
    ensure_folder_path('environments')

    Puppet.debug("#{@name} simpkv plugin for #{@root_path} configured")
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
      err_msg = "Key specifies a folder at '#{key_file}'"
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
        err_msg = "Delete of '#{key_file}' failed: #{e.message}"
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
          err_msg = "Folder delete of '#{dir}' failed: #{e.message}"
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
      err_msg = "Key specifies a folder at '#{key_file}'"
    else
      file = nil
      begin
        # To ensure all threads are not sharing the same file descriptor
        # do **NOT** use a File.open block!
        file = File.open(key_file, 'r')

        Timeout::timeout(@lock_timeout_seconds) do
          file.flock(File::LOCK_EX)
        end

        value = file.read
        file.close # lock released with close
        file = nil

      rescue Errno::ENOENT
        err_msg = "Key not found at '#{key_file}'"
      rescue Errno::EACCES
        err_msg = "Cannot read '#{key_file}' as #{user}:#{group}. \n"
        err_msg += ">>> Enable '#{group}' group read AND write access on '#{key_file}' to fix."
      rescue Timeout::Error
        err_msg = "Timed out waiting for lock of key file '#{key_file}'"
      rescue Exception => e
        err_msg = "Key retrieval at '#{key_file}' failed: #{e.message}"
      ensure
        # make sure lock is released even on failure
        file.close unless file.nil?
      end
    end
    { :result => value, :err_msg => err_msg }
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
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def list(keydir)
    result = nil
    err_msg = nil
    dir = File.join(@root_path, keydir)
    if Dir.exist?(dir)
      result = { :keys => {}, :folders => [] }
      Dir.glob(File.join(dir,'*')).each do |entry|
        if File.directory?(entry)
          result[:folders] << File.basename(entry)
        else
          key = entry.gsub(@root_path + File::SEPARATOR,'')
          key_result = get(key)
          unless key_result[:result].nil?
            result[:keys][File.basename(key)] = key_result[:result]
          end
        end
      end
      result[:folders].sort!
    else
       err_msg = "Key folder '#{keydir}' not found"
    end

    { :result => result, :err_msg => err_msg }
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

    file = nil
    key_file = File.join(@root_path, key)
    begin
      # ensure relative directory for the key file is present
      keydir = File.dirname(key)
      ensure_folder_path(keydir) unless keydir == '.'

      # create/update a key file
      new_file = !File.exist?(key_file)

      # To ensure all threads are not sharing the same file descriptor
      # do **NOT** use a File.open block!
      # Also, don't use 'w' as it truncates file before the lock is obtained
      file = File.open(key_file, File::RDWR|File::CREAT)

      Timeout::timeout(@lock_timeout_seconds) do
        # only wrap timeout around flock, so we don't end up with partially
        # modified files
        file.flock(File::LOCK_EX)
      end

      file.rewind
      file.write(value)
      file.flush
      file.truncate(file.pos)
      file.close # lock released with close
      file = nil

      if new_file || ( File.stat(key_file).uid == user_id )
        # we set the permissions here, instead of when the file was opened,
        # so that the user's umask is ignored
        # NOTE: Group writable setting is specifically to support `simp passgen`
        # operations implemented with `puppet apply` and run as root:puppet.
        # Do not want `simp passgen` to create a file/directory that
        # subsequent `puppet agent` runs as puppet:puppet will not be able
        # to manage.
        File.chmod(0660, key_file)
      end
      success = true

    rescue Timeout::Error
      success = false
      err_msg = "Timed out waiting for lock of key file '#{key_file}'"
    rescue Errno::EACCES
      success = false
      err_msg = "Cannot write to '#{key_file}' as #{user}:#{group}. \n"
      err_msg += ">>> Enable '#{group}' group read AND write access on '#{key_file}' to fix."
    rescue Exception => e
      success = false
      err_msg = "Key write to '#{key_file}' failed: #{e.message}"
    ensure
      file.close unless file.nil?
    end

    { :result => success, :err_msg => err_msg }
  end

  ###### Internal Methods ######

  # Ensures that the relative path to a key is present and the process can read
  # and write to each sub-directory in the path
  #
  # @param keydir Relative path to a key
  #
  # @raise RuntimeError if process cannot read and write to any sub-directory
  #   in the path
  def ensure_folder_path(keydir)
    Dir.chdir(@root_path) do
      path = Pathname.new(keydir)
      path.descend do |path|
        if Dir.exist?(path)
          verify_dir_access(path.to_s)
        else
          # Group writable setting is specifically to support `simp passgen`
          # operations implemented with `puppet apply` and run as root:puppet.
          # Do not want `simp passgen` to create a file/directory that
          # subsequent `puppet agent` runs as puppet:puppet will not be able
          # to manage.
          FileUtils.mkdir(path.to_s, :mode => 0770)
        end
      end
    end
  end

  # Determines the appropriate root path to files managed by this plugin and
  # then ensures it is available and has the appropriate permissions
  #
  # * If no root directory is specified in options, preferentially defaults to
  #   '/var/simp/simpkv/<name>', but uses '<Puppet[:vardir]>/simp/simpkv/<name>'
  #   as a fallback.
  # * Creates root directory if it does not exist
  #
  # @param options Hash of global simpkv and backend-specific options
  #
  # @return Root path
  #
  # @raise RuntimeError if any required configuration is missing from options,
  #   the root directory can be created when missing, or the root directory
  #   exists but cannnot be read/modified by this process
  def ensure_root_path(options)
    root_path = nil
    backend = options['backend']
    default_root_path_var = File.join('/', 'var', 'simp', 'simpkv', @name)
    default_root_path_puppet_vardir = File.join(Puppet.settings[:vardir], 'simp', 'simpkv', @name)

    if options['backends'][backend].has_key?('root_path')
      root_path = options['backends'][backend]['root_path']
    elsif Dir.exist?(default_root_path_var)
      root_path = default_root_path_var
      Puppet.debug("simpkv plugin #{@name}: Using existing default root path '#{root_path}'")
    elsif Dir.exist?(default_root_path_puppet_vardir)
      root_path = default_root_path_puppet_vardir
      Puppet.debug("simpkv plugin #{@name}: Using existing default root path '#{root_path}'")
    else
      root_path = default_root_path_var
      Puppet.debug("simpkv plugin #{@name}: Using default root path '#{root_path}'")
    end

    if Dir.exist?(root_path)
      verify_dir_access(root_path)
    else
      begin
        FileUtils.mkdir_p(root_path)
      rescue Exception => e
        if options['backends'][backend].has_key?('root_path')
          # someone made an explicit config error
          err_msg = "Unable to create configured root path '#{root_path}'.\n"
          err_msg += ">>> Ensure '#{group}' group can create '#{root_path}' to fix."
          raise(err_msg)
        else
          # try again using a fallback default that should work for 'puppet agent' runs
          begin
            FileUtils.mkdir_p(default_root_path_puppet_vardir)
            Puppet.warning("simpkv plugin #{name}: Unable to create root path " +
            "'#{root_path}'. Defaulting to '#{default_root_path_puppet_vardir}'")
            root_path = default_root_path_puppet_vardir
          rescue Exception => e
            # our fallback default didn't work...
            err_msg = "Unable to create default root path '#{root_path}'.\n"
            err_msg += ">>> Ensure '#{group}' group can create '#{root_path}' to fix."
            raise(err_msg)
          end
        end
      end

      # set permissions on the root directory
      # NOTE: Group writable setting is specifically to support `simp passgen`
      # operations implemented with `puppet apply` and run as root:puppet.
      # Do not want `simp passgen` to create a file/directory that subsequent
      # `puppet agent` runs as puppet:puppet will not be able to manage.
      begin
        FileUtils.chmod(0770, root_path)
      rescue Exception => e
        raise("Unable to set permissions on #{root_path}: #{e.message}")
      end
    end

    root_path
  end

  # @return Process gid
  def group_id
    Process.gid
  end

  # @return Process group name
  def group
    return @group unless @group.nil?

    @group = Etc.getgrgid(group_id).name
    @group
  end

  # @return Process uid
  def user_id
    Process.uid
  end

  # @return Process user name
  def user
    return @user unless @user.nil?

    @user = Etc.getpwuid(user_id).name
    @user
  end

  # Verifies that the process has read/write permissions in the directory
  #
  # @param dir Directory to verify
  # @raise RuntimeError if process cannot read and write to the directory
  def verify_dir_access(dir)
    begin
      Dir.entries(dir)

      # We can read the directory, now make sure we can write to it
      stat = File.stat(dir)
      write_access = false
      if (stat.uid == user_id)
        # we own the dir, so go ahead and enforce desired permissions
        FileUtils.chmod(0770, dir)
        write_access = true
      elsif (stat.gid == group_id) && ( (stat.mode & 00070) == 0070 )
        write_access = true
      elsif (stat.mode & 00007) == 0007
        #  Yuk! Should we warn?
        write_access = true
      end

      unless write_access
        err_msg = "Cannot modify '#{dir}' as #{user}:#{group}. \n"
        err_msg += ">>> Enable '#{group}' group read AND write access on '#{dir}' to fix."
        raise(err_msg)
      end
    rescue Errno::EACCES
      err_msg = "Cannot access '#{dir}' as #{user}:#{group}. \n"
      err_msg += ">>> Enable '#{group}' group read AND write access on '#{dir}' to fix."
      raise(err_msg)
    end
  end

end
