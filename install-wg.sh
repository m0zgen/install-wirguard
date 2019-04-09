#!/bin/bash
# Created by Yevgeniy Goncharov, https://sys-adm.in
#

SERVER_IP=$(hostname -I | cut -d' ' -f1)

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

echo -e "net.ipv4.conf.all.forwarding=1\nnet.ipv6.conf.all.forwarding" > /etc/sysctl.d/99-wireguard.conf

# Configure Server & Client
mkdir /etc/wireguard && cd /etc/wireguard && bash -c 'umask 077; touch wg0-server.conf'

wg genkey > /etc/wireguard/private-server.key
private_server_key=$(cat /etc/wireguard/private-server.key)

wg pubkey < /etc/wireguard/private-server.key > public-server.key
public_server_key=$(cat /etc/wireguard/public-server.key)

wg genkey > /etc/wireguard/private-client.key
private_client_key=$(cat /etc/wireguard/private-client.key)

wg pubkey < /etc/wireguard/private-client.key > public-client.key
public_client_key=$(/etc/wireguard/public-client.key)

cat > /etc/wireguard/wg0-server.conf <<_EOF_
[Interface]
Address = 10.0.0.1/24
ListenPort = 36666
PrivateKey = ${private_server_key}

[Peer]
PublicKey = ${public_client_key}
AllowedIPs = 10.0.0.2/32
_EOF_

cat > /etc/wireguard/wg0-client.conf <<_EOF_
[Interface]
Address = 10.0.0.2/24
PrivateKey = ${private_client_key}

[Peer]
PublicKey = ${public_server_key}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:36666
PersistentKeepalive = 15
_EOF_

chmod 600 client.conf && chmod 600 wg0-server.conf
systemctl enable wg-quick@wg0-server && systemctl start wg-quick@wg0-server

qrencode -t ansiutf8 < wg0_client.conf
