# Common LDAP configuration needed to set up and access the LDAP
# instances containing simpkv data.
# - One instance will be TLS enabled and the other will not.
#
require_relative 'validate_ldap_entry'
shared_context 'ldap server configuration' do

  # FIXME
  # - This test configures the ldap_plugin to use the root dn and password
  #   for each instance as its admin user, instead of a specific bind user
  #   and password for the simpkv subtree within the instance.
  let(:base_dn) { 'dc=simp' }
  let(:root_dn) { 'cn=Directory_Manager'  }
  let(:simpkv_base_dn) { "ou=simpkv,o=puppet,#{base_dn}"}
  let(:admin_dn) { root_dn }

  let(:ldap_instances) { {
    'simp_data_without_tls' => {
      # ds389::instance config
      :base_dn        => base_dn,
      :root_dn        => root_dn,
      :root_pw        => 'P@ssw0rdP@ssw0rd!N0TLS',
      :port           => 387,

      # simpkv ldap_plugin config
      :simpkv_base_dn => simpkv_base_dn,
      :admin_dn       => admin_dn,
      :admin_pw       => 'P@ssw0rdP@ssw0rd!N0TLS',
      :admin_pw_file  => '/etc/simp/simp_data_without_tls_pw.txt',

      # ldapi URI for ldapi tests and for clearing out data during test prep
      :ldapi_uri      => 'ldapi://%2fvar%2frun%2fslapd-simp_data_without_tls.socket'
    },

    'simp_data_with_tls'    => {
      # ds389::instance config
      :base_dn        => base_dn,
      :root_dn        => root_dn,
      :root_pw        => 'P@ssw0rdP@ssw0rd!TLS',
      :port           => 388,  # for StartTLS
# FIXME put this back once ds389 module is fixed
#      :secure_port    => 637,
      :secure_port    => 636,

      # simpkv ldap_plugin config
      :simpkv_base_dn => simpkv_base_dn,
      :admin_dn       => admin_dn,
      :admin_pw       => 'P@ssw0rdP@ssw0rd!TLS',
      :admin_pw_file  => '/etc/simp/simp_data_with_tls_pw.txt',

      # ldapi URI for ldapi tests and for clearing out data during test prep
      :ldapi_uri      => 'ldapi://%2fvar%2frun%2fslapd-simp_data_with_tls.socket'
    }

  } }

  # PKI general
  let(:certdir) { '/etc/pki/simp-testing/pki' }

  # Method object to validate key/folder entries in an LDAP instance
  let(:validator) { method(:validate_ldap_entry) }
end

