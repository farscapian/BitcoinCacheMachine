#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

# include the docker binary in our path.
PATH="$PATH:/snap/bin"
export PATH="$PATH"

# PASSWORD for PIHOLE
PASSWORD=
TRUSTED_INTERFACE=
UNTRUSTED_DMZ_INTERFACE=

for i in "$@"; do
    case $i in
        --password=*)
            PASSWORD="${i#*=}"
            shift
        ;;
        --trusted-interface=*)
            TRUSTED_INTERFACE="${i#*=}"
            shift
        ;;
        --untrusted-dmz-interface=*)
            UNTRUSTED_DMZ_INTERFACE="${i#*=}"
            shift
        ;;
        *)
            # unknown option
        ;;
    esac
done

if [ -z $PASSWORD ]; then
    echo "ERROR: PASSWORD must be defined. Use the --password=\"password\" syntax."
    exit
fi

ZONE_DIR="$HOME/.local/bcm/fw/zones"
function runPihole() {
    NAME="$1"
    IP="$2"
    INT="$3"
    SUBNET="$4"
    GATEWAY="$5"
    
    if docker ps -a | grep "$NAME-pihole"; then
        docker kill "$NAME-pihole"
        sleep 3
        docker system prune -f
    fi
    
    sudo rm -rf "$ZONE_DIR/$NAME"
    mkdir -p "$ZONE_DIR/$NAME"
    sudo docker run -d \
    --name "$NAME-pihole" \
    --privileged \
    --net=host \
    --cap-add NET_ADMIN \
    -e TZ="America/Chicago" \
    -v "$ZONE_DIR/$NAME/etc-pihole/:/etc/pihole/" \
    -v "$ZONE_DIR/$NAME/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
    --dns=127.0.0.1 --dns=1.1.1.1 \
    --restart=unless-stopped \
    --hostname "pihole.$NAME" \
    -e DNS1="1.1.1.1" \
    -e DNS2="8.8.8.8" \
    -e DNSSEC="true" \
    -e IPv6="false" \
    -e WEBPASSWORD="$PASSWORD" \
    -e VIRTUAL_HOST="pihole" \
    -e ServerIP="$IP" \
    -e PROXY_LOCATION="pihole.$NAME" \
    pihole/pihole:latest
    
    #            -p "$IP":53:53/tcp \
    #            -p "$IP":53:53/udp \
    #            -p "$IP":80:80/tcp \
    #            -p "$IP":443:443/tcp \
    
    echo "Starting up '$NAME-pihole' container."
    for i in $(seq 1 20); do
        if [ "$(sudo docker inspect -f "{{.State.Health.Status}}" $NAME-pihole)" == "healthy" ] ; then
            printf ' OK'
            echo -e "\n$(sudo docker logs pihole 2> /dev/null | grep 'password:') for your pi-hole: https://${IP}/admin/"
        else
            sleep 3
            printf '.'
        fi
        
        if [ $i -eq 20 ] ; then
            echo -e "\nTimed out waiting for Pi-hole start, consult check your container logs for more info (\`docker logs pihole\`)"
            #exit 1
        fi
    done;
    
    sudo ufw allow from any to "$IP" port 67 proto udp
    sudo ufw allow from any to "$IP" port 68 proto udp
    sudo ufw allow from any to "$IP" port 80 proto tcp
    sudo ufw allow from any to "$IP" port 53
    
}

# if the trusted interface is defined, configure it.
if [ ! -z "$TRUSTED_INTERFACE" ]; then
    runPihole lan 192.168.5.3 "$TRUSTED_INTERFACE" 192.168.5.0/24 192.168.5.1
fi

if [ ! -z "$UNTRUSTED_DMZ_INTERFACE" ]; then
    runPihole wireless 192.168.99.1 "$UNTRUSTED_DMZ_INTERFACE" 192.168.99.0/24
fi

#sudo shutdown -r now
