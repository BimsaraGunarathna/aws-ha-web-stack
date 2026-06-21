#trivy:ignore:DS-0002
#trivy:ignore:DS-0026
# Reproducible toolbox for validating, linting, security-scanning, and testing
# this Terraform project. Pinned versions so every run -- local or CI -- uses
# the exact same tooling.
FROM debian:bookworm-slim

ARG TERRAFORM_VERSION=1.15.6
ARG TFLINT_VERSION=0.53.0
ARG TRIVY_VERSION=0.58.1
ARG CHECKOV_VERSION=3.2.334

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Terraform
RUN curl -fsSLo /tmp/tf.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && unzip /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip

# tflint
RUN curl -fsSLo /tmp/tflint.zip \
      "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
    && unzip /tmp/tflint.zip -d /usr/local/bin && rm /tmp/tflint.zip

# trivy
RUN curl -fsSLo /tmp/trivy.tar.gz \
      "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
    && tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy && rm /tmp/trivy.tar.gz

# checkov
RUN pip3 install --no-cache-dir --break-system-packages "checkov==${CHECKOV_VERSION}"

WORKDIR /work
COPY . .

# Default: run the full check suite.
ENTRYPOINT ["bash", "ci/run-checks.sh"]
