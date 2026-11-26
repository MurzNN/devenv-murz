#!/usr/bin/env bash

docker build --progress=plain -t devenv-node . && \
docker run -d --rm --name devenv-node-run devenv-node && \
echo "Container started, attaching to it..." && \
docker exec -it devenv-node-run /usr/bin/bash; \
echo "Stopping container..." && \
docker stop devenv-node-run