# frozen_string_literal: true

require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap_plugin using ldapi'

describe 'ldap_plugin using ldapi' do
  include_context('ldap server configuration')

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

  hosts_with_role(hosts, 'ldap_server').each do |host|
    context "simpkv ldap_plugin on #{host} using ldapi" do
      it_behaves_like 'simpkv functions test', host do
        let(:common_ldap_config) {{
          'ldap_uri'      => "ldapi://%2fvar%2frun%2fslapd-#{ldap_instance}.socket",
          'admin_pw_file' =>  admin_pw_file
        }}

        let(:options) {{
          :type            => 'ldap',
          :backend_configs => {
            # All backend instances are using same LDAP server
            :class_keys           => common_ldap_config,
            :specific_define_keys => common_ldap_config,
            :define_keys          => common_ldap_config,
            :default              => common_ldap_config
          }
        }}
      end
    end
  end
end
