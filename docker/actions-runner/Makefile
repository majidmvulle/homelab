sinclude .env

export $(shell sed 's/=.*//' .env 2>/dev/null)

RUNNER_VERSION ?= 2.336.0

help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## docker/build: build docker image, takes version as argument example, docker/build version=v0.0.1
docker/build:
	@if [ -z "$(version)" ]; then \
		echo "Missing version, call it like 'make docker/build version=v0.0.1'"; \
		exit 1; \
	fi
	@echo "Building docker image version=$(version) with base runner $(RUNNER_VERSION)"
	@docker buildx build --platform linux/amd64,linux/arm64 \
		--build-arg RUNNER_VERSION=$(RUNNER_VERSION) \
		--tag ghcr.io/your-org/actions-runner:$(version) \
		-f Dockerfile .

## docker/push: builds and pushes multi-arch docker image directly to ghcr
docker/push:
	@if [ -z "$(version)" ]; then \
		echo "Missing version, call it like 'make docker/push version=v0.0.1'"; \
		exit 1; \
	fi
	@echo "Building and pushing multi-arch docker image version=$(version)"
	@docker buildx build --push --platform linux/amd64,linux/arm64 \
		--build-arg RUNNER_VERSION=$(RUNNER_VERSION) \
		--tag ghcr.io/your-org/actions-runner:$(version) \
		-f Dockerfile .
