#!/bin/bash

# Variables
nodename=`hostname`
domain=`hostname -d`
project="harbor"
openssl_sub="/C=AU/ST=Victoria/L=Melbourne/O=Oracle/OU=OLSC/CN=$nodename"
sslpath="/etc/$project/ssl"

function certs {

  mkdir -p $sslpath ; chmod 755 $sslpath

  echo "===== Generating CA Private Key for CA and CA Certificate ====="
  openssl genrsa -out $sslpath/ca.key 4096
  openssl req -x509 -new -nodes -sha512 -days 365 \
  -key $sslpath/ca.key -out $sslpath/ca.crt \
  -subj $openssl_sub

  echo "===== Generating Server Key and CSR ====="
  openssl genrsa -out $sslpath/`hostname`.key 4096
  openssl req -sha512 -new \
    -key $sslpath/`hostname`.key -out $sslpath/`hostname`.csr \
  -subj $openssl_sub

  echo "===== Generating Server Key and CSR ====="
cat > "$sslpath/v3.ext" <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
EOF
  echo -e "DNS.1=$domain" >> $sslpath/v3.ext
  echo -e "DNS.2=$nodename" >> $sslpath/v3.ext


  openssl x509 -req -sha512 -days 365 \
    -extfile $sslpath/v3.ext \
    -CA $sslpath/ca.crt -CAkey $sslpath/ca.key -CAcreateserial \
    -in $sslpath/`hostname`.csr \
    -out $sslpath/`hostname`.crt
 
openssl x509 -inform PEM -in $sslpath/`hostname`.crt -out $sslpath/`hostname`.cert

} # End certs

####### MAIN ##########

cd /root/

certs

wget https://github.com/goharbor/harbor/releases/download/v2.0.2/harbor-online-installer-v2.0.2.tgz >/dev/null

yum -y install docker-engine docker-compose
systemctl enable docker
systemctl start docker

tar -xvzf harbor-online-installer-v2.0.2.tgz
cd harbor
cp harbor.yml.tmpl harbor.yml

mkdir -p /data/cert
cp $sslpath/`hostname`.crt /data/cert/
cp $sslpath/`hostname`.key /data/cert/

sed -i -e "s/reg.mydomain.com/`hostname`/g" harbor.yml
sed -i -e "s/certificate: \/your\/certificate\/path/certificate: \/data\/cert\/$nodename.crt/g" harbor.yml
sed -i -e "s/private_key: \/your\/private\/key\/path/private_key: \/data\/cert\/$nodename.key/g" harbor.yml

mkdir -p /etc/docker/certs.d/$nodename/
cp $sslpath/`hostname`.cert /etc/docker/certs.d/$nodename/ 
cp $sslpath/`hostname`.key /etc/docker/certs.d/$nodename/
cp $sslpath/ca.crt /etc/docker/certs.d/$nodename/

systemctl restart docker
cp $sslpath/`hostname`.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
./prepare


./install.sh --with-clair

echo -e "\n===== Done =====\n"
echo "http://192.168.56.131"
echo "Username: admin"
echo "Password: Harbor12345"
echo -e "\n===== Demo =====\n"
echo -e "You can now create project, e.g. Staging and Users."
echo -e "Tag and Push as you wish\n" 
echo -e "docker pull container-registry-sydney.oracle.com/os/oraclelinux:7-slim"
echo -e "docker tag container-registry-sydney.oracle.com/os/oraclelinux:7-slim harbor.vagrant.vm/staging/oraclelinux:7-slim"
echo -e "docker login harbor.vagrant.vm"
echo -e "docker push harbor.vagrant.vm/staging/oraclelinux:7-slim"
