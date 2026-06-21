# Convenience wrapper around the verification suite.
# Run everything locally with `make check`, or in the container with `make docker-check`.

IMAGE := tf-ci
TF    := terraform

.PHONY: help fmt fmt-check init validate lint security test check docker-build docker-check clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

fmt: ## Auto-format all Terraform files
	$(TF) fmt -recursive

fmt-check: ## Verify formatting (CI gate)
	$(TF) fmt -check -recursive

init: ## Init without a backend (for validation/testing)
	$(TF) init -backend=false -input=false

validate: init ## Validate the configuration
	$(TF) validate

lint: ## Run tflint with the AWS ruleset
	tflint --init
	tflint --recursive

security: ## Run trivy + checkov config scans
	trivy config .
	checkov -d . --config-file .checkov.yaml

test: init ## Run the mocked, offline Terraform test suite
	$(TF) test

check: fmt-check validate lint test ## Run all hard gates

docker-build: ## Build the pinned test container
	docker build -t $(IMAGE) .

docker-check: docker-build ## Run the full suite in the container against the LIVE tree
	docker run --rm -e HOME=/tmp -u "$$(id -u):$$(id -g)" \
	  -v "$$(pwd)":/work -w /work $(IMAGE)

clean: ## Remove local Terraform working files
	rm -rf .terraform .terraform.lock.hcl
