
require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'simpkv client setup'

describe 'simpkv client setup' do
  include_context('ldap server configuration')

  # FIXME Can't compile manifests with simpkv functions unless the files containing
  #       the admin passwords already exists on each host
  context 'Ensure LDAP password files for clients exists prior to using simpkv functions' do
    let(:manifest) { <<-EOM
      file { '/etc/simp': ensure => 'directory' }

      file { '#{ldap_instances['simp_data_without_tls'][:admin_pw_file]}':
          ensure  => present,
          owner   => 'root',
          group   => 'root',
          mode    => '0400',
          content => Sensitive('#{ldap_instances['simp_data_without_tls'][:admin_pw]}')
      }

      file { '#{ldap_instances['simp_data_with_tls'][:admin_pw_file]}':
          ensure  => present,
          owner   => 'root',
          group   => 'root',
          mode    => '0400',
          content => Sensitive('#{ldap_instances['simp_data_with_tls'][:admin_pw]}')
      }
      EOM
    }
    hosts.each do |host|
      it 'should create admin pw file needed by ldap plugin' do
        apply_manifest_on(host, manifest, :catch_failures => true)
      end
    end
  end

  context 'Ensure openldap-clients package is installed on clients prior to using simpkv functions' do
    it 'should install openlap-clients package' do
      install_package_unless_present_on(hosts, 'openldap-clients')
    end
  end
end
