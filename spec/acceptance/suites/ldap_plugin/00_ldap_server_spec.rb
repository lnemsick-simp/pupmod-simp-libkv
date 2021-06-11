# frozen_string_literal: true

require 'spec_helper_acceptance'
require_relative 'ldap_server_configuration_context'

test_name 'ldap server setup'

describe 'ldap server setup' do
  include_context('ldap server configuration')
  let(:bootstrap_ldif) { File.read(File.join(__dir__, 'files', 'bootstrap.ldif')) }

  hosts.each do |host|
    context "host set up on #{host}" do
      it 'has a proper FQDN' do
        on(host, "hostname #{fact_on(host, 'fqdn')}")
        on(host, 'hostname -f > /etc/hostname')
      end

#FIXME remove this when done debugging
      it 'has vim installed' do
        on(host, 'yum install -y vim')
      end
    end
  end

  # FIXMEs
  # - This test does not yet use a SIMP profile to set up the simp_data LDAP
  #   instance.
  # - This test manually works around the lack of schema management in
  #   simp/ds389 (SIMP-9676).
  hosts_with_role(hosts, 'ldap_server').each do |host|
    context "LDAP server set up on #{host}" do
      let(:manifest) do
        'include ds389'
      end

      let(:hieradata) do
        {
          'ds389::instances'          => {
            'simp_data_without_tls' => {
              'base_dn'                => ldap_instances['simp_data_without_tls'][:base_dn],
              'root_dn'                => ldap_instances['simp_data_without_tls'][:root_dn],
              'root_dn_password'       => ldap_instances['simp_data_without_tls'][:root_pw],
              'listen_address'         => '0.0.0.0',
              'port'                   => ldap_instances['simp_data_without_tls'][:port],
              'bootstrap_ldif_content' => bootstrap_ldif
            },

            'simp_data_with_tls'    => {
              'base_dn'                => ldap_instances['simp_data_with_tls'][:base_dn],
              'root_dn'                => ldap_instances['simp_data_with_tls'][:root_dn],
              'root_dn_password'       => ldap_instances['simp_data_with_tls'][:root_pw],
              'listen_address'         => '0.0.0.0',
              'port'                   => ldap_instances['simp_data_with_tls'][:port],
# FIXME put this back once ds389 module is fixed
#              'secure_port'            => ldap_instances['simp_data_with_tls'][:secure_port],
              'bootstrap_ldif_content' => bootstrap_ldif,
              'enable_tls'             => true,
              'tls_params'             => {
                'source' => certdir
              }
            }
          }
        }
      end

      it 'works with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'applies a simpkv custom schema to non-TLS instance' do
        ldap_instances.each do |instance,config|
          src = File.join(__dir__, 'files', '70simpkv.ldif')
          dest = "/etc/dirsrv/slapd-#{instance}/schema/70simpkv.ldif"
          scp_to(host, src, dest)
          on(host, "chown dirsrv:dirsrv #{dest}")
          on(host, %Q{schema-reload.pl -Z #{instance} -D "#{config[:root_dn]}" -w "#{config[:root_pw]}" -P LDAPI})
          on(host, "egrep 'ERR\s*-\s*schemareload' /var/log/dirsrv/slapd-#{instance}/errors",
            :acceptable_exit_codes => [1])
        end
      end
    end
  end

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
end