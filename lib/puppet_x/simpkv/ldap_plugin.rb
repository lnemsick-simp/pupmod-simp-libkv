# Plugin implementation of an interface to an LDAP key/value store
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
# DO NOT CHANGE THE LINE BELOW!!!!
plugin_class = Class.new do
  require 'facter'
  require 'pathname'
  require 'set'

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
  # * `ldap_uri`:   Required. The LDAP server URI.
  #                 - This can be a ldapi socket path or an ldap/ldaps URI
  #                   specifying host and port.
  #                 - When using an 'ldap://' URI with StartTLS, `enable_tls`
  #                   must be true and `tls_cert`, `tls_key`, and `tls_cacert`
  #                   must be configured.
  #                 - When using an 'ldaps://' URI, `tls_cert`, `tls_key`, and
  #                   `tls_cacert` must be configured.
  #
  # * `base_dn`:    Optional. The root DN for the 'simpkv' tree in LDAP.
  #                 - Defaults to 'ou=simpkv,o=puppet,dc=simp'
  #
  # * `admin_dn`:   Optional. The bind DN for simpkv administration.
  #                 FIXME - Defaults to 'cn=Directory_Manager'
  #
  # * `admin_pw_file`: Required. A file containing the simpkv adminstration
  #                    password.
  #
  # * `enable_tls`: Optional. Whether to enable TLS.
  #                 - Defaults to false when `ldap_uri` is an 'ldap:\\' or
  #                   'ldapi:\\' URI, otherwise defaults to true.
  #                 - When true `tls_cert`, `tls_key` and `tls_cacert` must
  #                   be set.
  #
  # * `tls_cert`:   Optional. Certificate file
  # * `tls_key`:    Optional. Key file
  # * `tls_cacert`: Optional. cacert file
  # * `retries`:    Optional. Number of times to retry an LDAP operation if the
  #                 server reports it is busy.
  #                 - Defaults to 1
  #
  # @param name Name to ascribe to this plugin instance
  # @param options Hash of global simpkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options
  #   FIXME other failures
  def configure(options)

    # Maintain list of folders that already exist to reduce the number of
    # unnecessary ldap add operations over the lifetime of this plugin instance
    @existing_folders = Set.new
    @instance_path = File.join('instances', @name.gsub(%r{^ldap/},''))

    # TODO switch to ldif_wrap when we drop support for EL7
    # - EL7 only supports ldif-wrap
    # - EL8 says it supports ldif_wrap (--help and man page), but actually
    #   accepts ldif-wrap or ldif_wrap
    @search_opts = '-o "ldif-wrap=no" -LLL'

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
        (options['backends'][ options['backend'] ]['type'] == 'ldap')
    )
      raise("Plugin misconfigured: #{options}")
    end

    parse_config(options['backends'][options['backend']])
    verify_ldap_setup
    ensure_instance_tree

    Puppet.debug("#{@name} simpkv plugin configured")
  end

  # @return unique identifier assigned to this plugin instance
  def name
    @name
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
    Puppet.debug("#{@name} delete(#{key})")
    full_key_path =  File.join(@instance_path, key)

    cmd = [
      @cmd_env,
      @ldapdelete,
      @base_opts,
      %Q{"#{path_to_dn(full_key_path)}"}
    ].join(' ')

    deleted = false
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        deleted = true
        done = true
      when 32  # "No such object"
        deleted = true
        done = true
      when 51  # 'Server is busy'
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    { :result => deleted, :err_msg => err_msg }
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
    Puppet.debug("#{@name} deletetree(#{keydir})")
    full_keydir_path =  File.join(@instance_path, keydir)

    cmd = [
      @cmd_env,
      @ldapdelete,
      @base_opts,
      '-r',
      %Q{"#{path_to_dn(full_keydir_path, false)}"}
    ].join(' ')

    deleted = false
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        deleted = true
        done = true
      when 32  # "No such object"
        deleted = true
        done = true
      when 51  # 'Server is busy'
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    if deleted
      @existing_folders.delete(full_keydir_path)
      parent_path = full_keydir_path + "/"
      @existing_folders.delete_if { |path| path.start_with?(parent_path) }
    end

    { :result => deleted, :err_msg => err_msg }
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
    Puppet.debug("#{@name} exists(#{key})")
    dn = nil
    scope = nil
    search_filter = ''
    if key.empty?
      dn = @base_dn
      scope = '-s base'
    else
      # don't know if the key path is to a key or a folder so need to create a
      # search filter for both an RDN of ou=<key> or an RD simpkvKey=<key>.
      full_key_path =  File.join(@instance_path, key)
      dn = path_to_dn(File.dirname(full_key_path), false)
      leaf = File.basename(key)
      search_filter = "(|(ou=#{leaf})(simpkvKey=#{leaf}))"
      scope = '-s one'
    end

    cmd = [
      @cmd_env,
      @ldapsearch,
      @base_opts,
      '-b', %Q{"#{dn}"},
      @search_opts,
      scope,
      %Q{"#{search_filter}"},
      '1.1'                   # only print out the dn, no attributes
    ].join(' ')

    found = false
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        # Parent DN exists, but search may or may not have returned a result.
        # Have to parse console output to see if a dn was returned.
        found = true if result[:stdout].match(%r{^dn: .*#{dn}})
        done = true
      when 32   # 'No such object'
        # Some part of the parent DN does not exist
        done = true
      when 51  # 'Server is busy'
        done = true if (retries == 0)
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    { :result => found, :err_msg => err_msg }
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
    Puppet.debug("#{@name} get(#{key})")
    full_key_path =  File.join(@instance_path, key)

    cmd = [
      @cmd_env,
      @ldapsearch,
      @base_opts,
      '-b', %Q{"#{path_to_dn(full_key_path)}"},
      @search_opts
    ].join(' ')

    value = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
          match = result[:stdout].match(/^simpkvJsonValue: (.*?)$/)
          if match
            value = match[1]
          else
            err_msg = "Key retrieval did not return key/value entry:"
            err_msg += "\n#{result[:stdout]}"
          end
          done = true
      when 51  # 'Server is busy'
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
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
  #   * :result - Hash of retrieved key/value pairs; nil if the
  #     retrieval operation failed
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def list(keydir)
    Puppet.debug("#{@name} list(#{keydir})")
    full_keydir_path =  File.join(@instance_path, keydir)

    cmd = [
      @cmd_env,
      @ldapsearch,
      @base_opts,
      '-b', %Q{"#{path_to_dn(full_keydir_path, false)}"},
      '-s', 'one',
      @search_opts
    ].join(' ')

    ldif_out = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        ldif_out = result[:stdout]
        done = true
      when 32  # "No such object"
        ldif_out = ''
        done = true
      when 51  # 'Server is busy'
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    list = nil
    unless ldif_out.nil?
      if ldif_out.empty?
        list = { :keys => {}, :folders => [] }
      else
        list = parse_list_ldif(ldif_out)
      end
    end

    { :result => list, :err_msg => err_msg }
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
    Puppet.debug("#{@name} put(#{key},...)")
    full_key_path =  File.join(@instance_path, key)

    # We want to add the key/value entry if it does not exist, but only modify
    # the value if it does. This is so that we do not update modifyTimestamp
    # unnecessarily. The tricky part is that at any point in this process,
    # something else could be modifying the database at the same time. So
    # there is no point in checking for the existence of the key's folders or
    # its key/value entry, because that info may not be accurate at the time
    # we request our changes.  Instead, try to add each node individually, and
    # handle any "Already exists" failures appropriately for the node type.

    results = nil
    ldap_results = ensure_folder_path( File.dirname(full_key_path) )
    if ldap_results[:success]
      # first try an add for the key/value entry
      ldif = entry_add_ldif(full_key_path, value)

      Puppet.debug("#{@name} Attempting add for #{full_key_path}")
      ldap_results = ldap_add(ldif, false)

      if ldap_results[:success]
        results = { :result => true, :err_msg => nil }
      elsif (ldap_results[:exitstatus] == 68)  # Already exists
        Puppet.debug("#{@name} #{full_key_path} already exists")
# FIXME move to update_value()
        current_result = get(key)
        if current_result[:result]
          if current_result[:result] != value
            Puppet.debug("#{@name} Attempting modify for #{full_key_path}")
            ldif = entry_modify_ldif(full_key_path, value)
            ldap_results = ldap_modify(ldif, false)
            if ldap_results[:success]
              results = { :result => true, :err_msg => nil }
            else
              results = { :result => false, :err_msg => ldap_results[:err_msg] }
            end
          else
            # no change needed
            Puppet.debug("#{@name} #{full_key_path} value already correct")
            results = { :result => true, :err_msg => nil }
          end
        else
          err_msg = "Failed to retrieve current value for comparison: #{current_result[:err_msg]}"
          results = { :result => false, :err_msg => err_msg }
        end
      else
        results = { :result => false, :err_msg => ldap_results[:err_msg] }
      end
    else
      results = { :result => false, :err_msg => ldap_results[:err_msg] }
    end

    results
  end

  ###### Internal Methods ######
  # Execute a command
  #
  # - Command should not contain pipes, as they can cause inconsistent
  #   results
  # - This method does not wrap the execution with a Timeout block, because
  #   the commands being executed by this plugin (ldapsearch, ldapadd, etc)
  #   have built-in timeout mechanisms.
  #
  def run_command(command)
    Puppet.debug( "#{@name} executing: #{command}" )
    out_pipe_r, out_pipe_w = IO.pipe
    err_pipe_r, err_pipe_w = IO.pipe
    pid = spawn(command, :out => out_pipe_w, :err => err_pipe_w)
    out_pipe_w.close
    err_pipe_w.close

    Process.wait(pid)
    exitstatus = $?.nil? ? nil : $?.exitstatus
    stdout = out_pipe_r.read
    out_pipe_r.close
    stderr = err_pipe_r.read
    err_pipe_r.close

    stderr = "#{command} failed:\n#{stderr}" if exitstatus != 0

    {
      :success    => (exitstatus == 0),
      :exitstatus => exitstatus,
      :stdout     => stdout,
      :stderr     => stderr
    }
  end


  # Ensures the basic tree for this instance is created below the base DN
  #   base DN
  #   | - instances
  #   | | - <instance name>
  #   | | | - globals
  #   | | | - environments
  #   | | --
  #   | --
  #   --
  def ensure_instance_tree
#FIXME fix this once the simpkv_adapter adds globals and environments to the path
=begin
    [
      File.join(@instance_path, 'globals'),
      File.join(@instance_path, 'environments')
    ].each do | folder|
      # Have already verified access to the base DN, so going to *assume* any
      # failures here are transient and will ignore them for now. If there is
      # a persistent problem, it will be caught in the first key storage
      # operation.
      ensure_folder_path(folder)
    end
=end
  end

  # Ensure all folders in a folder path are present.
  def ensure_folder_path(folder_path)
    Puppet.debug("#{@name} ensure_folder_path(#{folder_path})")
    # Handle each folder separately instead of all at once, so we don't have to
    # use log scraping to understand what happened...log scraping is fragile.
    ldif_file = nil
    folders_added = true
    results = nil
    Pathname.new(folder_path).descend do |folder|
      folder_str = folder.to_s
      next if @existing_folders.include?(folder_str)
      ldif = folder_add_ldif(folder_str)
      ldap_results = ldap_add(ldif, true)
      if ldap_results[:success]
        @existing_folders.add(folder_str)
      else
        folders_added = false
        results = {
          :success  => false,
          :exitcode => ldap_results[:exitcode],
          :err_msg  => ldap_results[:err_msg]
        }
        break
      end
    end

    results = { :success => true, :exitcode => 0, :err_msg => nil } if folders_added
    results
  end

  def ldap_add(ldif, ignore_already_exists = false)
    # Maintainers:  Comment out this line to see actual LDIF content when
    # debugging. Since may contain sensitive info, we don't want to allow this
    # output normally.
    #Puppet.debug( "#{@name} add ldif:\n#{ldif}" )
    ldif_file = Tempfile.new('ldap_add')
    ldif_file.puts(ldif)
    ldif_file.close

    cmd = [
      @cmd_env,
      @ldapadd,
      @base_opts,
      '-f', ldif_file.path
    ].join(' ')

    added = false
    exitstatus = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        added = true
        done = true
      when 68   # Already exists
        if ignore_already_exists
          added = true
        else
          err_msg = result[:stderr]
        end
        done = true
      when 51  # 'Server is busy'
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      exitstatus = result[:exitstatus]
      retries -= 1
    end

    { :success => added, :exitstatus => exitstatus, :err_msg => err_msg }
  ensure
    ldif_file.close if ldif_file
    ldif_file.unlink if ldif_file
  end

  def ldap_modify(ldif)
    # Maintainers:  Comment out this line to see actual LDIF content when
    # debugging. Since may contain sensitive info, we don't want to allow this
    # output normally.
    #Puppet.debug( "#{@name} modify ldif:\n#{ldif}" )
    ldif_file = Tempfile.new('ldap_add')
    ldif_file.puts(ldif)
    ldif_file.close

    cmd = [
      @cmd_env,
      @ldapmodify,
      @base_opts,
      '-f', ldif_file.path
    ].join(' ')

    modified = false
    exitstatus = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        modified = true
        done = true
      when 32   # 'No such object'
        # DN got removed out from underneath us. Going to just accept this
        # failure for now, as unclear the complication in the logic to turn
        # around and add the entry is worth it.
        err_msg = result[:stderr]
        done = true
      when 51  # 'Server is busy'
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      exitstatus = result[:exitstatus]
      retries -= 1
    end

    { :success => modified, :exitstatus => exitstatus, :err_msg => err_msg }
  ensure
    ldif_file.close if ldif_file
    ldif_file.unlink if ldif_file

  end

  def folder_add_ldif(folder)
    <<~EOM
      dn: #{path_to_dn(folder, false)}
      ou: #{File.basename(folder)}
      objectClass: top
      objectClass: organizationalUnit
    EOM
  end

  def entry_add_ldif(key, value)
    <<~EOM
      dn: #{path_to_dn(key)}
      objectClass: simpkvEntry
      objectClass: top
      simpkvKey: #{File.basename(key)}
      simpkvJsonValue: #{value}
    EOM
  end

  def entry_modify_ldif(key, value)
    <<~EOM
      dn: #{path_to_dn(key)}
      changetype: modify
      replace: simpkvJsonValue
      simpkvJsonValue: #{value}
    EOM
  end

  def path_to_dn(path, leaf_is_key = true)
    parts = path.split('/')
    dn = nil
    if parts.empty?
      dn = @base_dn
    else
      attribute = leaf_is_key ? 'simpkvKey' : 'ou'
      dn = "#{attribute}=#{parts.pop}"
      parts.reverse.each do |folder|
        dn += ",ou=#{folder}"
      end
      dn += ",#{@base_dn}"
    end

    dn
  end

  #
  # Extract, validate, and transform configuration
  # - Creates tmpfile for the admin_pw
  # - Translates configuration into @base_dn, @cmd_env, and @base_opts
  #   for use in the ldap commands (ldapsearch, ldapadd, etc)
  def parse_config(config)
    ldap_uri = config['ldap_uri']
    raise("Plugin missing 'ldap_uri' configuration") if ldap_uri.nil?

    # FIXME this regex for URI or socket can be better!
    unless ldap_uri.match(%r{^(ldapi:|ldap:|ldaps:)//\S.})
      raise("Invalid 'ldap_uri' configuration: #{ldap_uri}")
    end

    if config.key?('base_dn')
      # FIXME Fix characters that should be escaped or detect and reject?
      @base_dn = config['base_dn']
    else
      @base_dn = 'ou=simpkv,o=puppet,dc=simp'
      Puppet.debug("simpkv plugin #{name}: Using base DN #{@base_dn}")
    end

    admin_dn = nil
    if config.key?('admin_dn')
      admin_dn = config['admin_dn']
    else
      #FIXME Should not use admin for whole tree
      admin_dn = 'cn=Directory_Manager'
      Puppet.debug("simpkv plugin #{name}: Using simpkv admin DN #{admin_dn}")
    end

    admin_pw_file = config['admin_pw_file']
    raise("Plugin missing 'admin_pw_file' configuration") if admin_pw_file.nil?
    raise("Configured 'admin_pw_file' does not exist") unless File.exist?(admin_pw_file)

    enable_tls = nil
    if config.key?('enable_tls')
      enable_tls = config['enable_tls']
    elsif ldap_uri.match(/^ldaps:/)
      enable_tls = true
    else
      enable_tls = false
      if ldap_uri.match(/^ldap:/)
        Puppet.debug("simpkv plugin #{name}: Not using StartTLS")
      end
    end

    if enable_tls
      tls_cert = config['tls_cert']
      tls_key = config['tls_key']
      tls_cacert = config['tls_cacert']

      if tls_cert.nil? || tls_key.nil? || tls_cacert.nil?
        err_msg = "#{@name} simpkv plugin missing for TLS configuration:"
        err_msg += ' tls_cert, tls_key, and tls_cacert must all be set'
        raise(err_msg)
      end

      @cmd_env = [
        "LDAPTLS_CERT=#{tls_cert}",
        "LDAPTLS_KEY=#{tls_key}",
        "LDAPTLS_CACERT=#{tls_cacert}"
      ].join(' ')

      if ldap_uri.match(/^ldap:/)
        # StartTLS
        @base_opts = %Q{-ZZ -x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri}}
      else
        # TLS
        @base_opts = %Q{-x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri}}
      end

    else
      # unencrypted ldap or ldapi
      @cmd_env = ''
      @base_opts = %Q{-x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri}}
    end

    if config.key?('retries')
      @retries = config['retries']
    else
      @retries = 1
      Puppet.debug("simpkv plugin #{name}: Using retries = #{@retries}")
    end
  end

  def parse_list_ldif(ldif_out)
#dn: simpkvKey=key1,ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp
#objectClass: simpkvEntry
#objectClass: top
#simpkvKey: key1
#simpkvJsonValue: {"value":"key1 value","metadata":{}}
#
#dn: ou=app1,ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp
#ou: app1
#objectClass: top
#objectClass: organizationalUnit
#
#dn: ou=app2,ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp
#ou: app2
#objectClass: top
#objectClass: organizationalUnit
    folders = []
    keys = {}
    ldif_out.split(/^dn: /).each do |ldif|
      next if ldif.strip.empty?
      if ldif.match(/objectClass: organizationalUnit/i)
        rdn = ldif.split("\n").first.split(',').first
        folder_match = rdn.match(/^ou=(\S+)$/)
        if folder_match
          folders << folder_match[1]
        else
          Puppet.debug("Unexpected organizationalUnit entry:\n#{ldif}")
        end
      elsif ldif.match(/objectClass: simpkvEntry/i)
        key_match = ldif.match(/simpkvKey: (\S+)/i)
        if key_match
          key = key_match[1]
          value_match = ldif.match(/simpkvJsonValue: (\{.+?\})\n/i)
          if value_match
            keys[key] = value_match[1]
          else
             Puppet.debug("simpkvEntry missing simpkvJsonValue:\n#{ldif}")
          end
        else
           Puppet.debug("simpkvEntry missing simpkvKey:\n#{ldif}")
        end
      else
        Puppet.debug("Found unexpected object in simpkv tree:\n#{ldif}")
      end
    end
    { :keys => keys, :folders => folders }
  end

  # verifies ldap commands exists and can access the LDAP server at
  # the base DN
  #
  # Sets variables for ldap commands
  def verify_ldap_setup
    # make sure all the openldap-utils commands we need are available
    @ldapsearch = Facter::Core::Execution.which('ldapsearch')
    @ldapadd = Facter::Core::Execution.which('ldapadd')
    @ldapmodify = Facter::Core::Execution.which('ldapmodify')
    @ldapdelete = Facter::Core::Execution.which('ldapdelete')

    [ @ldapsearch, @ldapadd, @ldapmodify, @ldapdelete ].each do |cmd|
      if cmd.nil?
        raise("Missing required #{cmd} command.  Ensure openldap-clients RPM is installed")
      end
    end

    # verify simpkv base DN is accessible
    results = exists('')
    unless results[:result]
      err_msg = "Plugin could not access #{@base_dn}"
      err_msg += ": #{results[:err_msg]}" if results[:err_msg]
      raise(err_msg)
    end
  end
end

