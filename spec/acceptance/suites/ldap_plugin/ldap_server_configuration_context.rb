# Common LDAP configuration needed to set up and access the LDAP
# instance containing simpkv data
require_relative 'validate_ldap_entry'
shared_context 'ldap server configuration' do
  # FIXME
  # - This test configures the ldap_plugin to use the root dn and password,
  #   instead of a specific bind user and password for the simpkv subtree.
  #
  let(:ldap_instance) { 'simp_data' }
  let(:base_dn) { 'dc=simp' }
  let(:root_dn) { 'cn=Directory_Manager'  }
  let(:root_pw) { 'P@ssw0rdP@ssw0rd!' }
  let(:simpkv_base_dn) { "ou=simpkv,o=puppet,#{base_dn}"}
  let(:admin_dn) { root_dn }
  let(:admin_pw) { root_pw }
  # FIXME can't compile manifests unless this already exists on each host
  let(:admin_pw_file) { '/etc/simp/simpkv_pw.txt' }

  # intentionally pick non-standard port, as we expect port 389 to be
  # used in the LDAP instance for user account info
  let(:ldap_port) { 388 }

  let(:validator) { method(:validate_ldap_entry) }

  context 'FIXME ensure password file exists prior to using simpkv functions' do
    let(:manifest) { <<-EOM
      file { '/etc/simp': ensure => 'directory' }

      file { '#{admin_pw_file}':
          ensure  => present,
          owner   => 'root',
          group   => 'root',
          mode    => '0400',
          content => Sensitive('#{admin_pw}')
      }
      EOM
    }
    hosts.each do |host|
      it 'should create admin pw file needed by ldap plugin' do
        apply_manifest_on(host, manifest, :catch_failures => true)
      end
    end
  end
end

