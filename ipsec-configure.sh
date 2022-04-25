#!/bin/bash

set -x

[ $# -ne 7 ] && { echo "Usage: $0 <REMOTE_IP> <LOCAL_SUBNET> <REMOTE_SUBNET> <SECRET> <VRRP_ROLE> <INT_VIP> <EXT_VIP>"; exit 1; }

REMOTE_IP=$1
LOCAL_SUBNET=$2
REMOTE_SUBNET=$3
SECRET=$4
VRRP_ROLE=$5
INT_VIP=$6
EXT_VIP=$7
LOCAL_IP=$(echo $EXT_VIP | sed 's/\/.*//')
VRRP_INT_INTERFACE=$(ip ro show $INT_VIP | grep -Eo "dev [a-z0-9]+" | sed 's/dev //')
VRRP_EXT_INTERFACE=$(ip ro show 0.0.0.0/0 | grep -Eo "dev [a-z0-9]+" | sed 's/dev //')


# Configure sysctl to forward traffic
sudo cat << EOF > /etc/sysctl.d/99-vpn-ipsec.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF
sudo sysctl -p /etc/sysctl.d/99-vpn-ipsec.conf

# Install packages
sudo apt update
sudo apt install -y strongswan keepalived
sudo systemctl enable strongswan-starter

# Create IPsec config
sudo cat << EOF > /etc/ipsec.conf
config setup
        charondebug="all"
        uniqueids=yes
        strictcrlpolicy=no

conn site-to-site-vpn
        type=tunnel
        authby=secret
        left=%defaultroute
        leftid=${LOCAL_IP}
        leftsubnet=${LOCAL_SUBNET}
        right=${REMOTE_IP}
        rightsubnet=${REMOTE_SUBNET}
        ike=aes256-sha2_256-modp1024!
        esp=aes256-sha2_256!
        keyingtries=0
        ikelifetime=1h
        lifetime=8h
        dpddelay=30
        dpdtimeout=120
        dpdaction=restart
        auto=start
EOF

# Create IPsec secret
sudo cat << EOF > /etc/ipsec.secrets
${LOCAL_IP} ${REMOTE_IP} : PSK "${SECRET}"
EOF

# Configure VRRP
sudo cat << EOF > /usr/local/sbin/notify-ipsec.sh
#!/bin/bash
TYPE=\$1
NAME=\$2
STATE=\$3
case \$STATE in
        "MASTER") /usr/sbin/ipsec restart
                  ;;
        "BACKUP") /usr/sbin/ipsec stop
                  ;;
        "FAULT")  /usr/sbin/ipsec stop
                  exit 0
                  ;;
        *)        /usr/bin/logger "ipsec unknown state"
                  exit 1
                  ;;
esac
EOF
sudo chmod a+x /usr/local/sbin/notify-ipsec.sh
sudo cat << EOF > /etc/keepalived/keepalived.conf
vrrp_sync_group G1 {
    group {
        EXT
        INT
    }
    notify "/usr/local/sbin/notify-ipsec.sh"
}

vrrp_instance INT {
    state ${VRRP_ROLE}
    interface ${VRRP_INT_INTERFACE}
    virtual_router_id 11
    priority 25
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass ${SECRET}
    }
    virtual_ipaddress {
        ${INT_VIP}
    }
    nopreempt
    garp_master_delay 1
}

vrrp_instance EXT {
    state ${VRRP_ROLE}
    interface ${VRRP_EXT_INTERFACE}
    virtual_router_id 22
    priority 25
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass ${SECRET}
    }
    virtual_ipaddress {
        ${EXT_VIP}
    }
    nopreempt
    garp_master_delay 1
}
EOF
sudo systemctl restart keepalived
sudo systemctl enable keepalived

# Show status
sudo ipsec status
