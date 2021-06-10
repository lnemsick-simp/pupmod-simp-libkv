def validate_ldap_entry(path, type, puppet_env, operation, config, host)
  result = false
  #FIXME missing environments or globals
  instance_path = File.join('instances', config['id'])
  full_path = puppet_env.nil? ? File.join(instance_path, path) : File.join(instance_path, puppet_env, path)
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
  [
    'ldapsearch',
    '-x',
    "-y #{config['admin_pw_file']}",
    "-D #{config['admin_dn']}",
    "-H #{config['ldap_uri']}",
    '-s base',
    "-b #{dn}",
    '-o "ldif_wrap=no"',
    '-LLL',
    '1.1'
  ].join(' ')
end
