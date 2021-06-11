require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap_plugin using ldap without TLS'

describe 'ldap_plugin using ldap without TLS' do
  include_context('ldap server configuration')

  hosts_with_role(hosts, 'ldap_server').each do |server|
    let(:server_fqdn) { fact_on(server, 'fqdn').strip }
    let(:ldap_uri) { "ldap://#{server_fqdn}:#{ldap_instances['simp_data_without_tls'][:port]}" }

    hosts_with_role(hosts, 'client').each do |client|
      context "simpkv ldap_plugin on #{client} using ldap without TLS to #{server}" do
        let(:common_ldap_config) {{
          'ldap_uri'      => ldap_uri,
          'base_dn'       => ldap_instances['simp_data_without_tls'][:simpkv_base_dn],
          'admin_dn'      => ldap_instances['simp_data_without_tls'][:admin_dn],
          'admin_pw_file' => ldap_instances['simp_data_without_tls'][:admin_pw_file]
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

        it_behaves_like 'simpkv functions test', client
      end
    end
  end
end
