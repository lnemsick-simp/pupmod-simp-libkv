# Plugin implementation of an interface to an LDAP key/value store
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
plugin_class = Class.new do
  require 'facter'

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
  # *
  #
  # @param name Name to ascribe to this plugin instance
  # @param options Hash of global simpkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options
  #   FIXME other failures
  def initialize(name, options)
    @name = name

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

    # create instance tree structure if it does not exist?
    #
    @search_opts= '-o ldif_wrap=no -LLL'

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
      dn = base_dn
      scope = '-s base'
    else
      # don't know if the key path is to a key or a folder so need to create a
      # search filter for both an ou=RDN or simpkvKey=RDN.
      dn = path_to_dn(File.dirname(key), false)
      leaf = File.basename(key)
      search_filter = "(|(ou=#{leaf})(simpkvKey=#{leaf}))"
      scope = '-s one'
    end

    # ldapsearch -x -w "P@ssw0rdP@ssw0rd" -D "cn=Directory_Manager" -H ldapi://%2fvar%2frun%2fslapd-simp_kv.socket -b "ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp" -s one -o ldif_wrap=no "(|(ou=app1)(simpkvKey=app1))" -LLL 1.1
    cmd = [
      @cmd_env,
      @ldapsearch,
      @base_opts
      '-b', dn,
      @search_opts
      scope,
      %Q{"#{search_filter}"},
      '1.1'                   # only print out the dn, no attributes
    ]

    found = nil
    error_msg = nil
    result = run_command(cmd.join)
    if result[:exitstatus] == 0
      # Parent DN exists, but search may or may not have returned a result.
      # Have to parse console output to see if a dn was returned
      if result[:stdout].match(%r{^dn: .*#{dn}})
        found = true
      else
        found = false
      end
    elsif result[:exitstatus] == 32  # 'no such object'
      # Some part of the parent DN does not exist
      found = false
    else
      error_msg = result[:stderr]
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

    # 1. construct DN
    # 2. search
    # ldapsearch -x -w "P@ssw0rdP@ssw0rd" -D "cn=Directory_Manager" -H ldapi://%2fvar%2frun%2fslapd-simp_kv.socket -b "simpkvKey=key1,ou=production,ou=environments,ou=default,ou=simpkv,o=puppet,dc=simp" -o ldif_wrap=no -LLL
    # 3. parse results
    # if success
    #    # will be successful even if search returns nothing
    #    return key info or nil
    # else
    #    return failure info
    # end
    # FIXME: insert code that connects to the backend an affects the get
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
    # at any point in this process, something else could be modifying 
    # the database at the same time, so need to allow "Already exists" failures.
    results = get(key)
    if results[:result].nil?
      results = create_entry(key, value)
    else
      if results[:result] != value
        results = modify_entry(key, value)
      else
        # don't overwrite if the value is corect, because that
        # unnecessarily changes the LDAP modify time
        results = { :result => true, :err_msg => nil }
      end
    end

    results
  end

  ###### Internal Methods ######

  def create_entry(key, value)
    folders_to_create = []
    Pathname.new(File.dirname(key)).ascend do |folder|
      break if exists(path)[:result]
      folders_to_create << folder
    end

    ldif = ''
    folders_to_create.reverse.each do |folder|
      ldif += <<~EOM
        ###########
        dn: #{path_to_dn(folder, false)}
        ou: #{File.basename(folder)}
        objectClass: top
        objectClass: organizationalUnit

      EOM
    end

    ldif += <<~EOM
      ###########
      dn: #{path_to_dn(key)}
      objectClass: simpkvEntry
      objectClass: top
      simpkvKey: #{File.basename(key)}
      simpkvJsonValue: #{value}
    EOM

    file = Tempfile.new('ldap_create_entry')
    file.puts(ldif)
    file.close
# do we need the continuous -c option when we have folders to create
# doesn't do what we want, returns the last failed return code
# Need to iterate through each dir and ignore 68 failures (in case someone else is
# creating dir at the same time)
#
# maybe better to run exists
    cmd = [
      @cmd_env,
      @ldapadd,
      @base_opts
      '-b', dn,
      @search_opts
      scope,
      %Q{"#{search_filter}"},
      '1.1'                   # only print out the dn, no attributes
    ]

  ensure
    file.close if file
    file.unlink if file
  end

  def modify_entry(key, value)
  end

  def path_to_dn(path, leaf_is_key = true)
    parts = path.split('/')
    dn = nil
    if parts.empty?
      dn = @base_dn
    else
      attribute = leaf_is_key ? 'simpkvKey' : 'ou'
      dn = "simpkvKey=#{parts.shift}"
      parts.each do |folder|
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

    if config['base_dn']
      @base_dn = config['base_dn']
    else
      @base_dn = 'ou=simpkv,o=puppet,dc=simp'
      Puppet.debug("simpkv plugin #{name}: Using base DN #{@base_dn}")
    end

    admin_dn = nil
    if config['admin_dn']
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
