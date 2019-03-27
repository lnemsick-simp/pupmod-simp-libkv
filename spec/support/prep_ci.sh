#!/bin/sh

dir=$(readlink -f $(dirname $0))
docker pull consul
docker run -d -p "10500:8500" -p "10501:8501" -v "$dir:/vagrant" -e CONSUL_LOCAL_CONFIG='{ "addresses": { "https":"0.0.0.0" }, "ports" : { "https" : 8501 }, "key_file" : "/vagrant/test/server.key", "cert_file" : "/vagrant/test/server.crt", "ca_file" : "/vagrant/test/ca.crt"}' consul:0.8.5
docker run -d -p "10504:8500" -p "10503:8501" -v "$dir:/vagrant" -e CONSUL_LOCAL_CONFIG='{ "addresses": { "https":"0.0.0.0" }, "ports" : { "https" : 8501 }, "key_file" : "/vagrant/test/server.key", "cert_file" : "/vagrant/test/server.crt", "ca_file" : "/vagrant/test/ca.crt", "verify_incoming": true}' consul:0.8.5
sleep 5
for i in $(docker ps -aq)
do
  docker inspect "${i}"
  docker logs "${i}"
done
curl -kvvvv https://172.17.0.1:10501
curl -kvvvv --cacert $dir/test/ca.pem --cert $dir/test/server.crt --key $dir/test/server.key https://172.17.0.1:10503
