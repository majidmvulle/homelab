sinclude .env

export $(shell sed 's/=.*//' .env)

help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## docker/build: build docker image, takes version as argument example, docker/build version=v0.0.1
docker/build:
	@if [ -z "$(version)" ]; then \
		echo "Missing version, call it like 'make docker/build version=v0.0.1'"; \
		exit 1; \
	fi
	@echo "Building docker image version=$(version)"
	@docker buildx build --load --platform linux/arm64 --platform linux/amd64 \
 	--tag ghcr.io/majidmvulle/homelab-infra/postgres-custom:$(version) \
 	-f Dockerfile .

## docker/push: pushes docker image to ghcr, takes version as argument example, docker/push version=v0.0.1
docker/push:
	@if [ -z "$(version)" ]; then \
		echo "Missing version, call it like 'make docker/push version=v0.0.1'"; \
		exit 1; \
	fi
	@echo "Pushing docker image version=$(version)"
	@docker push ghcr.io/majidmvulle/homelab-infra/postgres-custom:$(version)
