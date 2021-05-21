# Common LDAP configuration needed to set up and access the LDAP
# instance containing simpkv data
shared_context 'ldap server configuration' do
  # FIXME
  # - This test configures the ldap_plugin to use the root dn and password,
  #   instead of a specific bind user and password for the simpkv subtree.
  #
  let(:ldap_instance) { 'simp_data' }
  let(:base_dn) { 'dc=simp' }
  let(:root_dn) { 'cn=Directory_Manager'  }
  let(:root_pw) { 'P@ssw0rdP@ssw0rd!' }
  let(:admin_dn) { root_dn }
  let(:admin_pw) { root_pw }
  # FIXME can't compile manifests unless this already exists on each host
  let(:admin_pw_file) { '/etc/simp/simpkv_pw.txt' }

  # intentionally pick non-standard port, as we expect port 389 to be
  # used in the LDAP instance for user account info
  let(:ldap_port) { 388 }
end

