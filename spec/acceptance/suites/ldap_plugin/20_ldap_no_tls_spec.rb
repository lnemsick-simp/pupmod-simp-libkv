# frozen_string_literal: true

=begin

require 'spec_helper_acceptance'

test_name 'ldap_plugin using ldapi'

describe 'ldap_plugin using ldapi' do
  let(:ldap_instance) { 'simp_data' }
  let(:base_dn) { 'dc=simp' }
  let(:root_dn) { 'cn=Directory_Manager'  }
  let(:root_pw) { 'P@ssw0rdP@ssw0rd!' }
  let(:ldap_port) { 388 }
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
  # - This test configures the ldap_plugin to use the root dn and password,
  #   instead of a specific bind user and password for the simpkv subtree.
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
        }
      end

      it 'works with no errors' do
        set_hieradata_on(host, hieradata)
# FIXME WORKAROUND for package containing semanage not being installed
# and therefore selinux_port not finding suitable provider
        apply_manifest_on(host, manifest, expect_failures: true)
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

    context "simpkv ldap_plugin on #{host} using ldapi" do
      # can't count on the root password file
      let(:admin_pw_file) { '/etc/simp/simpkv_pw.txt' }
      let(:hieradata) {{

        'simpkv::backend::ldap_default' => {
          'type'      => 'ldap',
          'id'        => 'default',
          'ldap_uri'  => "ldapi://%2fvar%2frun%2fslapd-#{ldap_instance}.socket",
          'admin_pw_file' =>  admin_pw_file
        },
        'simpkv::options' => {
          'environment' => '%{server_facts.environment}',
          'softfail'    => false,
          'backends'    => {
            'default'=> "%{alias('simpkv::backend::ldap_default')}"
          }
        }
      }}

      let(:manifest) { <<-EOM
        file { '/etc/simp': ensure => 'directory' }

        file { '#{admin_pw_file}':
          ensure  => present,
          owner   => 'root',
          group   => 'root',
          mode    => '0400',
          content => Sensitive('#{root_pw}')
        }
        File['#{admin_pw_file}'] -> Class['simpkv_test::put']

        # Calls simpkv::put directly and via a Puppet-language function
        # * Stores values of different types.  Binary content is handled
        #   via a separate test.
        # * One of the calls to the Puppet-language function will go to the
        #   default backend
        class { 'simpkv_test::put': }

        # These two defines call simpkv::put directly and via the Puppet-language
        # function
        # * The 'define1' put operations should use the 'ldap/define_instance'
        #   backend instance.
        # * The 'define2' put operations should use the 'ldap/define_type'
        simpkv_test::defines::put { 'define1': }
        simpkv_test::defines::put { 'define2': }
      EOM
      }

      it 'should work with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end
    end
  end
end
=end
