# How-To Guide

A brief, copy-paste guide to set up credentials, deploy, and tear down this stack.
For architecture and design detail, see [README.md](README.md).

## What you get

An auto-scaling Nginx web tier behind an ALB, a managed PostgreSQL (RDS) database,
tiered security groups, and remote Terraform state. Defaults are dev-sized
(`t3.micro` instances, `db.t3.micro`, single-AZ) and serve plain **HTTP on :80** —
no TLS certificate required. (Set `enable_https = true` with an ACM cert to serve
HTTPS instead.)

## Prerequisites

- Terraform >= 1.5 and the AWS CLI installed
- An AWS account where you can create an IAM user (or assume an admin role)

## 1. Create a scoped deployer role and configure it locally

No admin access. The stack creates IAM roles, KMS keys, and Secrets Manager
secrets, so the deployer needs those permissions — but scoped to this project's
resources and region. The policy documents live in [`iam/`](iam/):

- [`iam/deployer-policy.json`](iam/deployer-policy.json) — EC2/VPC,
  Auto Scaling, ELB, RDS, CloudWatch/Logs, KMS, Secrets Manager (all restricted to
  `aws:RequestedRegion = us-east-1`), and IAM limited to `demo-webapp-*` roles
  and instance profiles only.
- [`iam/backend-policy.json`](iam/backend-policy.json) — S3 + DynamoDB
  scoped to the `myproject-tfstate-*` state buckets and the `terraform-lock` lock table.
- [`iam/trust-policy.json`](iam/trust-policy.json) — lets your
  existing IAM identity assume the role (replace `ACCOUNT_ID`).

> Deploying to a different region? Change `us-east-1` in
> `deployer-policy.json` to match. If you customise `project_name` or the
> state bucket/lock names, update the `demo-webapp-*` / `myproject-tfstate-*` /
> `terraform-lock` patterns to match.

**a. Create the two scoped policies and the role** (run once, with an existing
identity that can manage IAM):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Put your account ID into the trust policy.
sed "s/ACCOUNT_ID/$ACCOUNT_ID/" iam/trust-policy.json > /tmp/trust.json

aws iam create-policy --policy-name webapp-deployer-policy \
  --policy-document file://iam/deployer-policy.json
aws iam create-policy --policy-name webapp-backend-policy \
  --policy-document file://iam/backend-policy.json

aws iam create-role --role-name webapp-deployer \
  --assume-role-policy-document file:///tmp/trust.json

aws iam attach-role-policy --role-name webapp-deployer \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/webapp-deployer-policy
aws iam attach-role-policy --role-name webapp-deployer \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/webapp-backend-policy
```

**b. Add a local profile that assumes the role.** Append to `~/.aws/config`
(replace `ACCOUNT_ID`; `source_profile` is the identity allowed to assume it):

```ini
[profile webapp-deployer]
role_arn       = arn:aws:iam::ACCOUNT_ID:role/webapp-deployer
source_profile = default
region         = us-east-1
```

**c. Select the profile and verify:**

```bash
export AWS_PROFILE=webapp-deployer
aws sts get-caller-identity   # ARN should show assumed-role/webapp-deployer/...
```

> Already authenticate via SSO or another assumed role? You can attach the two
> policies to your existing role/permission set instead of creating a new one —
> just make sure `aws sts get-caller-identity` succeeds before continuing.

## 2. Bootstrap remote state (one-time per region)

Creates the S3 bucket + DynamoDB lock table that hold Terraform state.

```bash
cd bootstrap
terraform init
terraform apply \
  -var="aws_region=us-east-1" \
  -var="state_bucket_name=myproject-tfstate-<unique-suffix>"
cd ..
```

Note the `state_bucket` and `lock_table` outputs.

## 3. Initialize the backend

Point Terraform at the bucket from step 2 (region must match):

```bash
terraform init -reconfigure \
  -backend-config="bucket=myproject-tfstate-<unique-suffix>" \
  -backend-config="region=us-east-1"
```

## 4. Plan and apply

No certificate needed — the ALB serves HTTP on :80 by default:

```bash
terraform plan  -var-file=environments/dev.tfvars -var="aws_region=us-east-1"
terraform apply -var-file=environments/dev.tfvars -var="aws_region=us-east-1"
```

When apply finishes, get the app URL:

```bash
terraform output load_balancer_url
```

RDS takes several minutes to come up. To serve HTTPS instead, add
`-var="enable_https=true" -var="acm_certificate_arn=arn:aws:acm:us-east-1:<acct>:certificate/<id>"`
(the cert must be issued in the same region).

## 5. Tear down

RDS deletion protection is on by default, so disable it with an apply first, then
destroy (the NAT gateway and ALB bill hourly, so don't leave it running):

```bash
terraform apply   -var-file=environments/dev.tfvars -var="aws_region=us-east-1" -var="db_deletion_protection=false"
terraform destroy -var-file=environments/dev.tfvars -var="aws_region=us-east-1" -var="db_deletion_protection=false"
```

> Bootstrap resources (state bucket, lock table) are kept separately and are not
> removed by this destroy. Delete them manually only if you no longer need the state.

## Local checks (no AWS needed)

```bash
make check   # fmt, validate, lint, and the offline test suite
```

## Tips

- **Cheapest region for a test run:** `us-east-1` (or `us-east-2`).
- **Trim cost further:** set `desired_capacity`/`min_size = 1` and keep
  `db_multi_az = false` (the default).
- **Switch regions** by changing `aws_region`, the backend `region`, and (only if
  using HTTPS) a matching ACM cert ARN — all must agree.
