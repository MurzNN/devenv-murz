# devenv-murz

Containers with development environment and useful tools for Node.js development.

# Test locally

docker build --progress=plain -t devenv-murz . && echo "Built successfully, running..." && docker run -it --rm devenv-murz bash
