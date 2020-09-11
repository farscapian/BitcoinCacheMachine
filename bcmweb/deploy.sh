#!/bin/bash

set -Eeuox pipefail

# dockerd, localvm (virtualbox), awsvps
DEPLOY_TYPE=localvm

for i in "$@"; do
    case $i in
        --deploy-type=*)
            DEPLOY_TYPE="${i#*=}"
            shift
        ;;
        *)
            # unknown option
        ;;
    esac
done

source ./env

if docker-machine ls | grep -q "$VPS_NAME"; then
    docker-machine rm "$VPS_NAME" --force
fi

#sudo apt install jq moreutils dnsutils

if [ $DEPLOY_TYPE = 'localvm' ]; then
    docker-machine create --driver virtualbox \
    --virtualbox-cpu-count 4 \
    --virtualbox-memory 4096 \
    $VPS_NAME
elif [ $DEPLOY_TYPE = 'awsvps' ]; then
    if [ ! -f $HOME/.aws/credentials ]; then
        echo "ERROR: AWS Credential file in $HOME/.aws/credentials does not exist."
        exit
    fi

    source $HOME/.aws/credentials

    # creates a public VM in AWS and provisions the bcm website.
    docker-machine create --driver amazonec2 \
        --amazonec2-open-port 80 \
        --amazonec2-open-port 443 \
        --amazonec2-access-key "$AWS_ACCESS_KEY" \
        --amazonec2-secret-key "$AWS_SECRET_ACCESS_KEY" \
        --amazonec2-region "$AWS_REGION" \
        --amazonec2-ami $AWS_AMI_ID \
        "$VPS_NAME"
else
    # the stuff in this block came from publish_local.sh;
    # this is the default path when deploy-type = dockerd

    # first, let's build it so we're
    bash -c ./build_site.sh

    # pull nginx image
    NGINX_IMAGE="nginx:latest"
    if docker image list | grep -q "$NGINX_IMAGE"; then
        docker image pull "$NGINX_IMAGE"
    fi

    # if there's an existing running instance, let's kill it so we start from fresh.
    NGINX_CONTAINER_NAME="nginx-local-$SITE_NAME"
    if docker ps | grep -q "$NGINX_CONTAINER_NAME"; then
        docker kill "$NGINX_CONTAINER_NAME"
        sleep 3
    fi

    docker system prune -f >> /dev/null
    docker run -d --name="$NGINX_CONTAINER_NAME" \
    -p "127.0.0.1:8080:8080" \
    -v "$SITE_PATH/_site:/usr/share/nginx/html:ro" \
    -v "$(pwd)/site/nginx-local.conf:/etc/nginx/nginx.conf:ro" \
    "$NGINX_IMAGE"

    echo $(pwd)

    xdg-open "http://127.0.0.1:8080"

    exit
fi

# let's get the public DNS name of the remote instance
VPS_PUBLIC_IP="$(docker-machine ip $VPS_NAME)"
VPS_FQDN="$(dig -x $VPS_PUBLIC_IP +short)"
if [ -z $VPS_FQDN ]; then
    VPS_FQDN="$VPS_PUBLIC_IP"
fi

# create the nginx-config at /tmp/zeronet_nginx.conf
cat >/tmp/zeronet_nginx.conf <<EOL
events {
    worker_connections  1024;
}

http {
    server {

        server_name ${VPS_FQDN};

        # proxy all requests to the ZERONET_ADDRESS to the remote zeronet container.
        location / {
            proxy_pass http://zeronet:43110;
            proxy_set_header Host \$host;
            proxy_http_version 1.1;
            proxy_read_timeout 1h;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # # redirect requests to / to the ZERONET_ADDRESS
        # location / {
        #     return 301 http://${VPS_FQDN}/${BCM_ZERONET_ADDRESS};
        # }

        # listening on all interfaces inside the container (should be just 1 interface)
        listen 80;
    }
}
EOL

# send the file to the remote docker-machine.
docker-machine scp /tmp/zeronet_nginx.conf zeronet:/home/docker/zeronet_nginx.conf

# create zeronet.conf file
cat >/tmp/zeronet.conf <<EOL
[global]
ui_host = ${VPS_FQDN};
fileserver_port = 30310
data_dir = /root/data
log_dir = /root/logs
EOL

docker-machine scp /tmp/zeronet.conf zeronet:/home/docker/zeronet.conf

# direct the local docker client to target the remote dockerd
eval $(docker-machine env "$VPS_NAME")

# create docker volumes used by zeronet (persistent data)
docker volume create zeronet-data
docker volume create zeronet-logs

# create network for nginx to communicate to zeronet.
docker network create zeronetBrdige

#runs zeronet on VPS and downloads the bcm zeronet site
docker pull "$ZERONET_BASE_DOCKER_IMAGE"
docker build --build-arg BASE_IMAGE="$ZERONET_BASE_DOCKER_IMAGE" -t zeronet ./zeronet/

# file permissions on /root/zeronet.conf are -rw-r--r-- owned by root:root
docker run -d --name zeronet \
-v zeronet-data:/root/data \
-v zeronet-logs:/root/log \
-v /home/docker/zeronet.conf:/root/zeronet.conf:ro \
--network=zeronetBrdige \
zeronet

# give time for the container to spin up
sleep 20

# downloads the zeronet site
docker exec zeronet python3 zeronet.py siteDownload "$BCM_ZERONET_ADDRESS"

#docker exec zeronet wait-for-it -t 30 127.0.0.1:43110

# pull the nginx image down from dockerhub.
docker pull nginx:latest

# run nginx that proxies incoming requests to the local zeronet daemon
docker run -d --name=nginx \
-p "$VPS_PUBLIC_IP:80:80" \
-v /home/docker/zeronet_nginx.conf:/etc/nginx/nginx.conf:ro \
--network=zeronetBrdige \
nginx:latest

wait-for-it -t 30 "$VPS_PUBLIC_IP:80"

xdg-open "http://$VPS_PUBLIC_IP:80"
#curl http://$VPS_PUBLIC_IP:80 -v
