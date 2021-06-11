require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap_plugin using ldapi'

describe 'ldap_plugin using ldapi' do
  include_context('ldap server configuration')

  hosts_with_role(hosts, 'ldap_server').each do |host|
    context "simpkv ldap_plugin on #{host} using ldapi" do
      let(:common_ldap_config) {{
        'ldap_uri'      => "ldapi://%2fvar%2frun%2fslapd-#{ldap_instance}.socket",
        'base_dn'       => simpkv_base_dn,
        'admin_dn'      => admin_dn,
        'admin_pw_file' => admin_pw_file
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
    end
  end
end
