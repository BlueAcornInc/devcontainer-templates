.PHONY: help build clean test

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: build-commerce ## Build all devcontainers

build-commerce: ## Build the adobe commerce devcontainer
	devcontainer up --workspace-folder src/adobe-commerce-and-magento --remove-existing-container

generate-docs: ## generate docs for each devcontainer
	devcontainer templates generate-docs -p src/

publish: ## publish all devcontainers
	devcontainer templates publish -r ghcr.io -n doughatcher/devcontainer-templates ./src

ci: build publish ## Build and publish all devcontainers

clean: ## clean filesystem
	git clean -fdX -e .envrc src/**