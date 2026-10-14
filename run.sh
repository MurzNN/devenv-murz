#!/usr/bin/env bash

docker build --progress=plain -t devenv-murz . && \
docker run -d --rm --name devenv-murz-run devenv-murz && \
echo "Container started, attaching to it..." && \
docker exec -it devenv-murz-run /usr/bin/bash; \
echo "Stopping container..." && \
docker stop devenv-murz-run