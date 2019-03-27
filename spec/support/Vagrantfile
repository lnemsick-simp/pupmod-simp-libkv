# vim: set ft=ruby:
Vagrant.configure(2) do |config|
	ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'
	ENV['VAGRANT_NO_PARALLEL'] = 'yes'
	config.vm.define "consul-ssl" do |config|
		config.vm.synced_folder ".", "/vagrant"
		config.vm.provider "docker" do |d|
			d.image = "consul:0.9.2"
			d.has_ssh = false
			d.env = {
				"CONSUL_LOCAL_CONFIG" => '{
					"addresses": {
						"https":"0.0.0.0"
					},
					"ports" : {
						"https" : 8501
					},
					"key_file" : "/vagrant/test/server.key",
					"cert_file" : "/vagrant/test/server.crt",
					"ca_file" : "/vagrant/test/ca.crt"
				}'
			}
			d.ports = [
                                "10500:8500",
				"10501:8501",
			]
		end
	end
	config.vm.define "consul-ssl-auth" do |config|
		config.vm.synced_folder ".", "/vagrant"
		config.vm.provider "docker" do |d|
			d.image = "consul:0.9.2"
			d.has_ssh = false
			d.env = {
				"CONSUL_LOCAL_CONFIG" => '{
					"addresses": {
						"https":"0.0.0.0"
					},
					"ports" : {
						"https" : 8501
					},
					"key_file" : "/vagrant/test/server.key",
					"cert_file" : "/vagrant/test/server.crt",
					"ca_file" : "/vagrant/test/ca.crt",
                                        "verify_incoming" : true
				}'
			}
			d.ports = [
                                "10504:8500",
				"10503:8501",
			]
		end
	end
	config.vm.define "etcd" do |config|
		config.vm.synced_folder ".", "/vagrant", disabled: true
		config.vm.provider "docker" do |d|
			d.image = "elcolio/etcd"
			d.has_ssh = false
			d.ports = [
				"10379:2379",
			]
		end
	end
	# vagrant_root = File.dirname(__FILE__);
	# config.vm.define "puppet" do |config|
	# 	config.vm.synced_folder ".", "/vagrant", disabled: true
	# 	config.vm.provider "docker" do |d|
	# 		d.image = "simpproject/centos:7-ruby21"
	# 		d.has_ssh = true
	# 		d.volumes = [
	# 			"#{vagrant_root}:/vagrant:z",
	# 		]
	# 		d.cmd = [ "bash", "-c", "sudo yum install -y openssh-server && sudo /usr/sbin/sshd"]
	# 	end

	# end
end
