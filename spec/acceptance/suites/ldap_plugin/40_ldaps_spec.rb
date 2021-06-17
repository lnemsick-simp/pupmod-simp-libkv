require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap_plugin using ldap with TLS'

describe 'ldap_plugin using ldap with TLS' do
  include_context('ldap server configuration')
  let(:ldap_instance) { ldap_instances['simp_data_with_tls'] }

  hosts_with_role(hosts, 'ldap_server').each do |server|
    context "with LDAP server #{server}" do
      let(:server_fqdn) { fact_on(server, 'fqdn').strip }
      let(:ldap_uri) { "ldaps://#{server_fqdn}:#{ldap_instance[:secure_port]}" }

      hosts_with_role(hosts, 'client').each do |client|
        context "with LDAP client #{client}" do
          let(:client_fqdn) { fact_on(client, 'fqdn').strip }
          let(:tls_cert)   { "#{certdir}/public/#{client_fqdn}.pub" }
          let(:tls_key)    { "#{certdir}/private/#{client_fqdn}.pem" }
          let(:tls_cacert) { "#{certdir}/cacerts/cacerts.pem" }
          let(:common_ldap_config) {{
            'ldap_uri'      => ldap_uri,
            'base_dn'       => ldap_instance[:simpkv_base_dn],
            'admin_dn'      => ldap_instance[:admin_dn],
            'admin_pw_file' => ldap_instance[:admin_pw_file],
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

          context "ensure empty key store on #{server} for testing access from #{client}" do
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
              on(server, cmd, :accept_all_exit_codes => true)
            end
          end

          context "simpkv ldap_plugin on #{client} using ldap with TLS to #{server}" do
            it_behaves_like 'simpkv functions test', client
          end
        end
      end
    end
  end
end
