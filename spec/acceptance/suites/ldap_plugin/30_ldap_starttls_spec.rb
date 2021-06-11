require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap_plugin using ldap with StartTLS'

describe 'ldap_plugin using ldap with StartTLS' do
  include_context('ldap server configuration')

  hosts_with_role(hosts, 'ldap_server').each do |server|
    let(:server_fqdn) { fact_on(server, 'fqdn').strip }
    let(:ldap_uri) { "ldap://#{server_fqdn}:#{ldap_instances['simp_data_with_tls'][:port]}" }

    hosts_with_role(hosts, 'client').each do |client|
      let(:client_fqdn) { fact_on(client, 'fqdn').strip }
      let(:tls_cert)   { "#{certdir}/public/#{client_fqdn}.pub" }
      let(:tls_key)    { "#{certdir}/private/#{client_fqdn}.pem" }
      let(:tls_cacert) { "#{certdir}/cacerts/cacerts.pem" }

      context "simpkv ldap_plugin on #{client} using ldap with StartTLS to #{server}" do
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

        context "clear key store on #{server} for next test" do
          it 'should remove all ldap_plugin instance data to restore to an empty state' do
            cmd = [
              "LDAPTLS_CERT=#{tls_cert}",
              "LDAPTLS_KEY=#{tls_key}",
              "LDAPTLS_CACERT=#{tls_cacert}",
              'ldapdelete',
              '-ZZ',
              %Q{-D "#{common_ldap_config['admin_dn']}"},
              '-y', common_ldap_config['admin_pw_file'],
              '-H', common_ldap_config['ldap_uri'],
              '-r',
              %Q{"ou=instances,#{common_ldap_config['base_dn']}"}
            ].join(' ')
            on(server, cmd)
          end
        end
      end
    end
  end
end
