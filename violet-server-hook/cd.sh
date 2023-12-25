#!/bin/bash
set +x

# sync docker
docker stop scsbackend && docker rm $_
docker pull violet-dev/violet:latest

# download env-file for docker
aws s3api get-object --bucket violet-config --key .env.docker.prod .env.docker.prod

# setup docker
docker create --env-file ./.env.docker.prod \
                  --name violet \
                  --network host \
                  --add-host host.docker.internal:host-gateway \
                  violet-dev/violet:latest

# download env & copy to container
aws s3api get-object --bucket scs-config --key .prod.env .prod.env
docker cp .prod.env violet:/home/node/

# run docker
docker start violet
docker rmi $(docker images -q violet-dev/violet)

rm .env.docker.prod
rm .prod.env
