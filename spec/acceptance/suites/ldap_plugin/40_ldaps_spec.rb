require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap_plugin using ldap with TLS'

describe 'ldap_plugin using ldap with TLS' do
  include_context('ldap server configuration')

  hosts_with_role(hosts, 'ldap_server').each do |server|
    let(:server_fqdn) { fact_on(server, 'fqdn').strip }
    let(:ldap_uri) { "ldaps://#{server_fqdn}:#{ldap_instances['simp_data_with_tls'][:secure_port]}" }

    hosts_with_role(hosts, 'client').each do |client|
      let(:client_fqdn) { fact_on(client, 'fqdn').strip }
      let(:tls_cert)   { "#{certdir}/public/#{client_fqdn}.pub" }
      let(:tls_key)    { "#{certdir}/private/#{client_fqdn}.pem" }
      let(:tls_cacert) { "#{certdir}/cacerts/cacerts.pem" }

      context "simpkv ldap_plugin on #{client} using ldap with TLS to #{server}" do
        let(:common_ldap_config) {{
          'ldap_uri'      => ldap_uri,
          'base_dn'       => ldap_instances['simp_data_with_tls'][:simpkv_base_dn],
          'admin_dn'      => ldap_instances['simp_data_with_tls'][:admin_dn],
          'admin_pw_file' => ldap_instances['simp_data_with_tls'][:admin_pw_file],
          'enable_tls'    => true,
          'tls_cert'      => tls_cert,
          'tls_key'       => tls_key,
          'tls_cacert'    => tls_cacert,
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
