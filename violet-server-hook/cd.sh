#!/bin/bash
set +x

# sync docker
docker stop violet && docker rm $_
docker pull violetdev/violet:latest

# setup docker
docker create --name violet \
                  --network host \
                  --add-host host.docker.internal:host-gateway \
                  --restart always \
                  violetdev/violet:latest

# download env & copy to container
aws s3api get-object --bucket violet-config --key .prod.env .prod.env
docker cp .prod.env violet:/home/node/

# run docker
docker start violet
docker rmi $(docker images -q violetdev/violet)

rm .prod.env
