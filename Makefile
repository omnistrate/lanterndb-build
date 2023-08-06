.PHONY: all
all: deps build

.PHONY: deps
deps:
	git submodule update --init --recursive

.PHONY: multi-arch-build
multi-arch-build:
	docker buildx build --platform=linux/amd64,linux/arm64 -t lanterndb .

.PHONY: build
build: 
	docker build -t lanterndb .

.PHONY: run
run:
	docker-compose up -d

.PHONY: multi-arch-build-and-push
multi-arch-build-and-push:
	docker buildx build --platform=linux/amd64,linux/arm64 -t lanterndb . --push
