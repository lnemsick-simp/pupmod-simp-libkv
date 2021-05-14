# Plugin implementation of an interface to an LDAP key/value store
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
plugin_class = Class.new do
  require 'facter'
  require 'pathname'
  require 'set'

  # Reminder:  Do **NOT** try to set constants in this Class.new block.
  #            They don't do what you expect (are not accessible within
  #            any class methods) and pollute the Object namespace.

  ###### Public Plugin API ######

  # @return String. backend type
  def self.type
    'ldap'
  end

  # Construct an instance of this plugin using global and plugin-specific
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
  def initialize(name, options)
    @name = name

    # Maintain list of folders that already exist to reduce the number of
    # unnecessary ldap add operations over the lifetime of this plugin instance
    @existing_folders = Set.new
    @instance_path = File.join('instances', @name)
    @search_opts= '-o ldif_wrap=no -LLL'

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

    # create instance tree structure if it does not exist?
    #

    Puppet.debug("#{@name} simpkv plugin constructed")
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
    full_key_path =  File.join(@instance_path, key)

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
    full_keydir_path =  File.join(@instance_path, keydir)

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
    dn = nil
    scope = nil
    search_filter = ''
    if key.empty?
      dn = @base_dn
      scope = '-s base'
    else
      # don't know if the key path is to a key or a folder so need to create a
      # search filter for both an ou=RDN or simpkvKey=RDN.
      full_key_path =  File.join(@instance_path, key)
      dn = path_to_dn(File.dirname(full_key_path), false)
      leaf = File.basename(key)
      search_filter = "(|(ou=#{leaf})(simpkvKey=#{leaf}))"
      scope = '-s one'
    end

    # ldapsearch -x -w "P@ssw0rdP@ssw0rd" -D "cn=Directory_Manager" -H ldapi://%2fvar%2frun%2fslapd-simp_kv.socket -b "ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp" -s one -o ldif_wrap=no "(|(ou=app1)(simpkvKey=app1))" -LLL 1.1
    cmd = [
      @cmd_env,
      @ldapsearch,
      @base_opts,
      '-b', dn,
      @search_opts,
      scope,
      %Q{"#{search_filter}"},
      '1.1'                   # only print out the dn, no attributes
    ]

    found = false
    error_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd.join)
      switch(result[:exitstatus])
      case 0:
        # Parent DN exists, but search may or may not have returned a result.
        # Have to parse console output to see if a dn was returned.
        found = true if result[:stdout].match(%r{^dn: .*#{dn}})
        done = true
      case 32:  # 'No such object'
        # Some part of the parent DN does not exist
        done = true
      case 51: # 'Server is busy'
        done = true if (retries == 0)
      else
        error_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    { :result => found, :err_msg => error_msg }
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
    full_key_path =  File.join(@instance_path, key)

    # ldapsearch -x -w "P@ssw0rdP@ssw0rd" -D "cn=Directory_Manager" -H ldapi://%2fvar%2frun%2fslapd-simp_kv.socket -b "simpkvKey=key1,ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp" -o ldif_wrap=no -LLL
    cmd = [
      @cmd_env,
      @ldapsearch,
      @base_opts,
      '-b', path_to_dn(full_key_path),
      @search_opts
    ]

    value = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd.join)
      switch(result[:exitstatus])
      case 0:
          match = result[:stdout].match(/^simpkvJsonValue: (.*?)$/)
          if match
            value = match[1]
          else
            err_msg = "Key retrieval did not return key/value entry:"
            err_msg += "\n#{result[:stdout]}"
          end
          done = true
      case 51: # 'Server is busy'
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
    full_keydir_path =  File.join(@instance_path, keydir)

#ldapsearch -x -w "P@ssw0rdP@ssw0rd" -D "cn=Directory_Manager" -H ldapi://%2fvar%2frun%2fslapd-simp_kv.socket -b "ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp" -o ldif_wrap=no -LLL -s one
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


    # use scope parameter in ldapsearch to ensure only going 1 level deep
    # FIXME: insert  code that connects to the backend an affects the list
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
    full_key_path =  File.join(@instance_path, key)

    # We want to add the key/value entry if it does not exist but only modify
    # the value if it does, so that we do not update modifyTimestamp
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
      ldif = entry_add_ldif(key, value)
      ldap_results = ldap_add(ldif, false)

      if ldap_results[:success]
        results = { :result => true, :err_msg => nil }
      elsif (ldap_results[:exitstatus] == 68)  # Already exists
        ldif = entry_modify_ldif(key, value)
        ldap_results = ldap_modify(ldif, false)
        if ldap_results[:success]
          results = { :result => true, :err_msg => nil }
        else
          results = { :result => false, :err_msg => ldap_results[:err_msg] }
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
  end

  # Ensure all folders in a folder path are present.
  def ensure_folder_path(folder_path)
    # Handle each folder separately instead of all at once, so we don't have to
    # use log scraping to understand what happened...log scraping is fragile.
    ldif_file = nil
    folders_added = true
    results = nil
    Pathname.new(folder_path).descend do |folder|
      next if @existing_folders.include?(folder)
      ldif = folder_add_ldif(folder)
      ldap_results = ldap_add(ldif, true)
      if ldap_results[:success]
        @existing_folders.add(folder)
      else
        folders_added = false
        results = { :success => false, :exitcode => ldap_results[:exitcode], :err_msg => ldap_results[:err_msg] }
        break
      end
    end

    results = { :success => true, :exitcode => 0, :err_msg => nil } if folders_added
    results
  end

  def ldap_add(ldif, ignore_already_exists = false)
    ldif_file = Tempfile.new('ldap_add')
    ldif_file.puts(ldif)
    ldif_file.close

    # ldapadd -x -w "P@ssw0rdP@ssw0rd" -D "cn=Directory_Manager" -H ldapi://%2fvar%2frun%2fslapd-simp_kv.socket -f /root/simp_kv/ldifs/app2_group1_key1.ldif
    cmd = [
      @cmd_env,
      @ldapadd,
      @base_opts,
      '-f', ldif_file.path
    ]

    added = false
    exitstatus = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd.join)
      switch(result[:exitstatus])
      case 0:
        added = true
        done = true
      case 68:  # Already exists
        if ignore_already_exists
          added = true
        else
          error_msg = result[:stderr]
        end
        done = true
      case 51: # 'Server is busy'
        if (retries == 0)
          error_msg = result[:stderr]
          done = true
        end
      else
        error_msg = result[:stderr]
        done = true
      end
      exitstatus = result[:exitstatus]
      retries -= 1
    end

    { :success => added, :exitstatus => exitstatus, :err_msg => error_msg }
  ensure
    ldif_file.close if ldif_file
    ldif_file.unlink if ldif_file
  end

  def ldap_modify(ldif)
    ldif_file = Tempfile.new('ldap_add')
    ldif_file.puts(ldif)
    ldif_file.close

    cmd = [
      @cmd_env,
      @ldapmodify,
      @base_opts,
      '-f', ldif_file.path
    ]

    modified = false
    exitstatus = nil
    error_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd.join)
      switch(result[:exitstatus])
      case 0:
        modified = true
        done = true
      case 32:  # 'No such object'
        # DN got removed out from underneath us. Going to just accept this
        # failure for now, as unclear the complication in the logic to turn
        # around and add the entry is worth it.
        error_msg = result[:stderr]
        done = true
      case 51: # 'Server is busy'
        if (retries == 0)
          error_msg = result[:stderr]
          done = true
        end
      else
        error_msg = result[:stderr]
        done = true
      end
      exitstatus = result[:exitstatus]
      retries -= 1
    end

    { :success => modified, :exitstatus => exitstatus, :err_msg => error_msg }
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
      @base_dn = config['base_dn']
    else
      @base_dn = 'ou=simpkv,o=puppet,dc=simp'
      Puppet.debug("simpkv plugin #{name}: Using base DN #{@base_dn}")
    end

    admin_dn = nil
    if config.key?('admin_dn')
      admin_dn = config['admin_dn']
    else
      #FIXME should not use admin for whole tree
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
        @base_opts = "-ZZ -x -D #{admin_dn} -y #{admin_pw_file} -H #{@ldap_uri}"
      else
        # TLS
        @base_opts = "-x -D #{admin_dn} -y #{admin_pw_file} -H #{@ldap_uri}"
      end

    else
      # unencrypted ldap or ldapi
      @cmd_env = ''
      @base_opts = "-x -D #{admin_dn} -y #{admin_pw_file} -H #{@ldap_uri}"
    end

    if config.key?('retries')
      @retries = config['retries']
    else
      @retries = 1
      Puppet.debug("simpkv plugin #{name}: Using retries = #{@retries}")
    end
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
        raise("Missing required #{cmd} command.  Ensure openldap-utils RPM is installed")
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

   # command should not contain pipes, as they can cause inconsistent
   # results
   def run_command(command)
      Puppet.debug( "Executing: #{command}" )
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

      {
        :success    => (exitstatus == 0),
        :exitstatus => exitstatus,
        :stdout     => stdout,
        :stderr     => stderr
      }
    end

end
