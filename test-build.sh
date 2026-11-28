#!/usr/bin/env bash

docker build --progress=plain -t devenv-node-test-build . && \
docker run -d --rm --name devenv-node-test-build devenv-node-test-build && \
echo "Container started, attaching to it..." && \
docker exec -it devenv-node-test-build /usr/bin/bash; \
echo "Stopping container..." && \
docker stop devenv-node-test-build