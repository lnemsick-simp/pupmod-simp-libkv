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
            ldap_instance => {
              'base_dn'                => base_dn,
              'root_dn'                => root_dn,
              'root_dn_password'       => root_pw,
              'listen_address'         => '0.0.0.0',
              'port'                   => ldap_port,
              'bootstrap_ldif_content' => bootstrap_ldif
            }
          }
#FIXME add an instance with tls and configure schema in it
        }
      end

      it 'works with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'applies a simpkv custom schema' do
        src = File.join(__dir__, 'files', '70simpkv.ldif')
        dest = "/etc/dirsrv/slapd-#{ldap_instance}/schema/70simpkv.ldif"
        scp_to(host, src, dest)
        on(host, "chown dirsrv:dirsrv #{dest}")
        on(host, %Q{schema-reload.pl -Z #{ldap_instance} -D "#{root_dn}" -w "#{root_pw}"})
        on(host, "egrep 'ERR\s*-\s*schemareload' /var/log/dirsrv/slapd-#{ldap_instance}/errors",
          :acceptable_exit_codes => [1])
      end
    end
  end
end
