#!/bin/bash
# Created by Yevgeniy Goncharov, https://sys-adm.in
#

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Vars
# ---------------------------------------------------\
SERVER_IP=$(hostname -I | cut -d' ' -f1)
WGSERVER_DATA="/etc/wireguard"
WGSERVER_CONFIG="$WGSERVER_DATA/wg0-server.conf"

WGCONFIG_DATA="$SCRIPT_PATH/wg-data"
WGCLIENT_CONFIG="$WGCONFIG_DATA/wg0-client.conf"

if [[ -d $WGCONFIG_DATA ]]; then
  echo "Folder $WGCONFIG_DATA exist!"
  rm -rf $WGCONFIG_DATA
  mkdir $WGCONFIG_DATA
else
  mkdir $WGCONFIG_DATA
fi

if [[ -d $WGSERVER_DATA ]]; then
  echo "Folder $WGSERVER_DATA exist!"
  rm -rf $WGSERVER_DATA
  mkdir $WGSERVER_DATA
else
  mkdir $WGSERVER_DATA
fi

# Install WG
curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
yum install nano epel-release -y && yum install wireguard-dkms wireguard-tools qrencode -y

modprobe wireguard && lsmod | grep wireguard

# Configure FW & Routing
firewall-cmd --permanent --zone=public --add-port=36666/udp
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --reload

sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv6.conf.all.forwarding=1

cat > /etc/sysctl.d/99-wireguard.conf <<_EOF_
net.ipv4.conf.all.forwarding=1
net.ipv6.conf.all.forwarding
_EOF_

# Configure Server & Client
private_server_key=$(wg genkey)
private_client_key=$(wg genkey)

public_server_key=$(echo $private_server_key | wg pubkey)
public_client_key=$(echo $private_client_key | wg pubkey)

echo $private_server_key $public_server_key
echo $private_client_key $public_client_key

touch $WGSERVER_CONFIG
umask 077 $WGSERVER_CONFIG

cat > $WGSERVER_CONFIG <<_EOF_
[Interface]
Address = 10.0.0.1/24
ListenPort = 36666
PrivateKey = ${private_server_key}

[Peer]
PublicKey = ${public_client_key}
AllowedIPs = 10.0.0.2/32
_EOF_

cat > $WGCLIENT_CONFIG <<_EOF_
[Interface]
Address = 10.0.0.2/24
PrivateKey = ${private_client_key}

[Peer]
PublicKey = ${public_server_key}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:36666
PersistentKeepalive = 15
_EOF_

chmod 600 $WGSERVER_CONFIG
systemctl enable wg-quick@wg0-server && systemctl restart wg-quick@wg0-server

qrencode -t ansiutf8 < $WGCLIENT_CONFIG
