.PHONY: help build clean test

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: clean build-commerce ## Build all devcontainers

build-commerce: ## Build the adobe commerce devcontainer
	devcontainer up --workspace-folder src/adobe-commerce-and-magento --remove-existing-container

generate-docs: ## generate docs for each devcontainer
	devcontainer templates generate-docs -p src/

publish: clean docker-login  ## publish all devcontainers
	devcontainer templates publish -r ghcr.io -n blueacorninc/devcontainer-templates ./src

ci: build publish ## Build and publish all devcontainers

docker-login: ## performs the correct login to ghcr.io for publishing
	echo $$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

clean: ## clean files from devcontainers before publishing
	git clean -Xd -f src/**
