#def validate_ldap_entry(path, host, backend_config, options =
# {:type => :key, :operation => :present, :puppet_env => 'production', :value => nil})
def validate_ldap_entry(path, type, puppet_env, operation, config, host)
  result = false
  instance_path = File.join('instances', config['id'])
  full_path = puppet_env.nil? ? File.join(instance_path, 'globals', path) : File.join(instance_path, 'environments', puppet_env, path)
  dn = nil
  if type == :key
    dn = "simpkvKey=#{File.basename(full_path)},#{build_folder_dn(File.dirname(full_path), config)}"
  elsif type == :folder
    dn = build_folder_dn(full_path, config)
  end

  if dn && ( (operation == :present) || (operation == :absent) )
    cmd = build_ldapsearch_cmd(dn, config)
    result = on(host, cmd, :accept_all_exit_codes => true)
    match = result.stdout.match(%r{^dn: .*#{dn}})
    result = (operation == :present) ? !match.nil? : match.nil?
  end

  result
end

def build_folder_dn(folder, config)
  parts = folder.split('/')
  dn = ''
  parts.reverse.each { |subfolder| dn += "ou=#{subfolder}," }
  dn += "#{config['base_dn']}"
  dn
end

def build_ldapsearch_cmd(dn, config)
  env = []
  auth_option = '-x'
  if config['enable_tls']
    env = [
      "LDAPTLS_CERT=#{tls_cert}",
      "LDAPTLS_KEY=#{tls_key}",
      "LDAPTLS_CACERT=#{tls_cacert}"
    ]
    if config['ldap_uri'].start_with?('ldap://')
      # StartTLS
      auth_option = '-ZZ'
    end
  end

  cmd = env + [
    'ldapsearch',
    auth_option,
    "-y #{config['admin_pw_file']}",
    "-D #{config['admin_dn']}",
    "-H #{config['ldap_uri']}",
    '-s base',
    "-b #{dn}",

    # TODO switch to ldif_wrap when we drop support for EL7
    # - EL7 only supports ldif-wrap
    # - EL8 says it supports ldif_wrap (--help and man page), but actually
    #   accepts ldif-wrap or ldif_wrap
    '-o "ldif-wrap=no"',
    '-LLL',
    '1.1'
  ]

  cmd.join(' ')
end
