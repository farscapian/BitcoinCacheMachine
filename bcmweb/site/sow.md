# Statement of Work

## Goal

The goal of this work should be to produce a set of scripts and associated files which 1) enables quick updates to the BCM Jekyll Website (hosted on a Keybase team git repo labeled 'bcmweb-jekyll'). The scripts 2) SHALL allow the jekyll site to be built, resulting in a static HTML site in the '_site' directory'. 3) The '_site' folder MUST be importable into an existing Zeronet site representing the system-of-record for the BCM website. (That is, the BCM website IS a Zeronet website). 4) The resulting Jekyll html site SHALL include the necessary `.js`, etc., files which enable integration with the Zeronet API.

The Zeronet site SHALL be hosted exclusively hosted over TOR with the exception of the following:

## Public Proxies 

The Zeronet site SHALL be made accessible to legacy clients using the URL `bitcoincachemachine.org` (already owned). At a minimum, Amazon Web Services shall be used in conjunction with `docker-machine` to create one or more Ubuntu 20.04 VPS instances. These instances SHALL run Zeronet and expose BCM zeronet site locally with the goal of serving the BCM zeronet site to external clients. A nginx container running on each VPS SHALL expose the Zeronet Site (running at 127.0.0.1:28953) to external clients. Once production-ready, DNS records for bitcoincachemachine.org will be configured to point at one or more VPSs configured to proxy the zeronet site. 

###Conversation with Derek

2 instances of nginx?  Yes.  The publish_local.sh runs a single docker container on your host machine at 127.0.0.1:8080. This one is meant to be run by a developer primarily to ensure that the jekyll website is presented in the correct way. Once the developer is satisfied, the jekyll website can be published to ZERONET (by publish, I mean the person with the private key for the site updates content.json). ANY host running zeronet can access websites at 127.0.0.1:43110/SITE_ADDRESS

Then there is the AWS host that will serve www.bitcoincachemachine.org over the public (untrusted) Internet. The IP of this AWS host will be resolvable from bitcoincachemachine.org. That AWS ubuntu host will run dockerd. There will be AT LEAST TWO docker containers: one running nginx and the other running zeronet. The NGINX configuration will translate incoming requests on the public IP address on port 80 and 443 (HTTP/HTTPS) to the ZERONET service running locally at 127.0.0.1:43110/SITE_ADDRESS.

## TOR onion site

In addition to proxying the BCM zeronet site to external clients over IPv4, a publicly-access TOR onion site SHALL be created to expose the site. This allows external clients using the Tor browser to access the website as well. It is sufficient to host the onion site on the SAME VPS that run the public proxies.


##########################################
#FILE 1
########################################

#!/bin/bash

# set the working directory to the location where the script is located
# since all file references are relative to this script
cd "$(dirname "$0")"

AWS_CLOUD_INIT_FILE=aws_docker_machine_cloud_init.yml

# creates a public VM in AWS and provisions the bcm website.
docker-machine create --driver amazonec2 \
    --amazonec2-open-port 80 \
    --amazonec2-open-port 443 \
    --amazonec2-access-key $AWS_ACCESS_KEY \
    --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
    --amazonec2-userdata $AWS_CLOUD_INIT_FILE \
    --amazonec2-region us-east-1 registry

eval $(docker-machine env registry)

# enable swarm mode so we can deploy a stack.
docker swarm init

# if $HOME/.abot/registry.config doesn't exist, create a new one. 
if [[ ! -f $HOME/.abot/registry.config ]]; then
    REGISTRY_HTTP_SECRET=$(apg -n 1 -m 30 -M CN)
    mkdir -p $HOME/.abot
    echo "REGISTRY_HTTP_SECRET="$REGISTRY_HTTP_SECRET >> $HOME/.abot/registry.config
else
    # if it does exist, source it.
    source $HOME/.abot/registry.config
fi


#private-registry-data

docker-machine ssh registry -- sudo apt-get update
docker-machine ssh registry -- sudo apt-get install -y software-properties-common add-apt-respository
docker-machine ssh registry -- sudo add-apt-repository ppa:certbot/certbot
docker-machine ssh registry -- sudo apt-get update
docker-machine ssh registry -- sudo apt-get -y install certbot 

docker-machine ssh registry -- mkdir -p /home/ubuntu/registry/<FIXME>
docker-machine ssh registry -- sudo certbot certonly --webroot -w /home/ubuntu/registry/<FIXME> -d <FIXME>.com -d registry.<FIXME>.com

env REGISTRY_HTTP_SECRET=$REGISTRY_HTTP_SECRET docker stack deploy -c registry.yml registry

wait-for-it -t 0 $(docker-machine ip registry):80


##########################################
#FILE 2
########################################

#!/bin/bash

source ./prod.env

if [[ $(env | grep AWS) = '' ]] 
then
  echo "AWS variables not set. Please source a env file."
  exit 1
fi

# creates a public VM in AWS and provisions the bcm website.
docker-machine create --driver amazonec2 \
    --amazonec2-open-port 80 \
    --amazonec2-open-port 443 \
    --amazonec2-access-key $AWS_ACCESS_KEY \
    --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
    --amazonec2-userdata $AWS_CLOUD_INIT_FILE \
    --amazonec2-region us-east-1 bcmweb01

sleep 5

docker-machine stop bcmweb01

sleep 10

docker-machine start bcmweb01

sleep 10

wait-for-it -t 0 $(docker-machine ip bcmweb01):22

docker-machine regenerate-certs -f bcmweb01

eval $(docker-machine env bcmweb01)

# bash -c ./provision.sh

# bash -c ./up.sh



##########################################
#FILE 3
########################################

#!/bin/bash

source ./prod.env

if [[ $(env | grep AWS) = '' ]] 
then
  echo "AWS variables not set. Please source a env file."
  exit 1
fi

# creates a public VM in AWS and provisions the bcm website.
docker-machine create --driver amazonec2 \
    --amazonec2-open-port 80 \
    --amazonec2-open-port 443 \
    --amazonec2-access-key $AWS_ACCESS_KEY \
    --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
    --amazonec2-userdata $AWS_CLOUD_INIT_FILE \
    --amazonec2-region us-east-1 bcmweb01

sleep 5

docker-machine stop bcmweb01

sleep 10

docker-machine start bcmweb01

sleep 10

wait-for-it -t 0 $(docker-machine ip bcmweb01):22

docker-machine regenerate-certs -f bcmweb01

eval $(docker-machine env bcmweb01)

# bash -c ./provision.sh

# bash -c ./up.sh

Installing Docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env zeronet