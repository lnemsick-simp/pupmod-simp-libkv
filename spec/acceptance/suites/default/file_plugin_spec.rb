require 'spec_helper_acceptance'

test_name 'libkv file plugin'

describe 'libkv file plugin' do
 let(:manifest) {
    <<-EOS
      file {'/var/simp/libkv':
        ensure => directory
      }

      # * keys set with direct libkv function calls should persist in the
      #   default for this class, /var/simp/libkv/file1
      # * keys set via libkv_test::put_function(), a Puppet language function
      #   that calls libkv functions, unfortunately will go to the non-specific
      #   default, /var/simp/libkv/file4, because the scope of the function does
      #   not know anything about the caller
      class { 'libkv_test::put': }

      # keys are set with direct libkv function calls should persist in the
      # default for any instance of this define, in /var/simp/libkv/file3
      libkv_test::defines::put { 'define1': }

      # keys are set with direct libkv function calls should persist in the
      # default for the specific instance of this define, in /var/simp/libkv/file2
      libkv_test::defines::put { 'define2': } # should persist in /var/simp/libkv/file3
    EOS
  }

  let(:hieradata) {{

    'libkv::backend::file1' => {
      'type'      => 'file',
      'id'        => 'file1',
      'root_path' => '/var/simp/libkv/file1'
    },

    'libkv::backend::file2' => {
      'type'      => 'file',
      'id'        => 'file2',
      'root_path' => '/var/simp/libkv/file2'
    },

    'libkv::backend::file3' => {
      'type'      => 'file',
      'id'        => 'file3',
      'root_path' => '/var/simp/libkv/file3'
    },

    'libkv::backend::file4' => {
      'type'      => 'file',
      'id'        => 'file4',
      'root_path' => '/var/simp/libkv/file4'
    },

   'libkv::options' => {
      'environment' => '%{server_facts.environment}',
      'softfail'    => false,
      'backends' => {
      'default.Class[Libkv_test::Put]'            => "%{alias('libkv::backend::file1')}",
      'default.Libkv_test::Defines::Put[define2]' => "%{alias('libkv::backend::file2')}",
      'default.Libkv_test::Defines::Put'          => "%{alias('libkv::backend::file3')}",
      'default'                                   => "%{alias('libkv::backend::file4')}",
      }

    }

  }}

  hosts.each do |host|

    context 'libkv put operation' do
      it 'should work with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

    end

    context 'libkv exist operation' do
    end

    context 'libkv get operation' do
    end

    context 'libkv list operation' do
    end

    context 'libkv delete operation' do
    end

    context 'libkv deletetree operation' do
    end

  end
end
