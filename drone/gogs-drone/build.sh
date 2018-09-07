#!/bin/bash

HOST_IP=$(ip addr show enp0s8 | grep inet -w | awk '{print $2}' | awk -F '/' '{print $1}')

GOGS_HOST=http://${HOST_IP}
GOGS_LOCAL=$(pwd)/gogs_data
GOGS_PORT=3000

DRONE_HOST=http://${HOST_IP}
DRONE_LOCAL=$(pwd)/drone_data
DRONE_PORT=9080
DRONE_SECRET=hello1234


docker run -d \
    --name=gogs \
    -p 10022:22 \
    -p ${GOGS_PORT}:3000 \
    -v ${GOGS_LOCAL}:/data \
    gogs/gogs


docker-compose -f - up -d << EOF
version: '2'

services:
  drone-server:
    image: drone/drone:0.8

    ports:
      - ${DRONE_PORT}:8000
      - 9000
    volumes:
      - /root/gogs-drone/drone_data:/var/lib/drone/
    restart: always
    environment:
      - DRONE_OPEN=true
      - DRONE_HOST=${DRONE_HOST}
      - DRONE_GOGS=true
      - DRONE_GOGS_URL=${GOGS_HOST}:${GOGS_PORT}
      - DRONE_SECRET=${DRONE_SECRET}

  drone-agent:
    image: drone/agent:0.8

    restart: always
    depends_on:
      - drone-server
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_SERVER=drone-server:9000
      - DRONE_SECRET=${DRONE_SECRET}
EOF
