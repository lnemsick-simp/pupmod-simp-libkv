require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap_plugin using ldapi'

describe 'ldap_plugin using ldapi' do
  include_context('ldap server configuration')

  # Arbitrarily using the 389ds instance configured without TLS, but could use
  # TLS-enabled instance instead
  let(:ldap_instance) { ldap_instances['simp_data_without_tls'] }

  hosts_with_role(hosts, 'ldap_server').each do |host|
    # As tests are currently written, don't need this... Just in case the test
    # files are reordered...
    context "ensure empty key store on #{host}" do
      it 'should remove all ldap_plugin instance data' do
        cmd = [
          'ldapdelete',
          '-x',
          %Q{-D "#{ldap_instance[:admin_dn]}"},
          '-y', ldap_instance[:admin_pw_file],
          '-H', ldap_instance[:ldapi_uri],
          '-r',
          %Q{"ou=instances,#{ldap_instance[:simpkv_base_dn]}"}
        ].join(' ')
        on(host, cmd, :accept_all_exit_codes => true)
      end
    end

    context "simpkv ldap_plugin on #{host} using ldapi" do
      let(:common_ldap_config) {{
        'ldap_uri'      => ldap_instance[:ldapi_uri],
        'base_dn'       => ldap_instance[:simpkv_base_dn],
        'admin_dn'      => ldap_instance[:admin_dn],
        'admin_pw_file' => ldap_instance[:admin_pw_file]
      }}

      let(:options) {{
        :backend_configs => {
          # All backend instances are of same type and use same LDAP server instance
          :class_keys           => {'type' => 'ldap'}.merge(common_ldap_config),
          :specific_define_keys => {'type' => 'ldap'}.merge(common_ldap_config),
          :define_keys          => {'type' => 'ldap'}.merge(common_ldap_config),
          :default              => {'type' => 'ldap'}.merge(common_ldap_config)
        },
        :validator       => validator
      }}

      it_behaves_like 'simpkv functions test', host

      context 'LDAP-specfic features' do

        # FIXME
        it 'should not change the modify timestamp of entries that have not changed'
      end

    end
  end
end
