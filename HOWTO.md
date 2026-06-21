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
- A clone of this repo (the `iam/*.json` policy documents are used in step 1)
- An AWS account with Console access to IAM (to create the policies and role)

## 1. Create the scoped deployer role from the AWS Console

No admin access. The stack creates IAM roles, KMS keys, and Secrets Manager
secrets, so the deployer needs those permissions — but scoped to this project's
resources (`aws-ha-web-stack-*`, `aws-ha-web-stack-tfstate-*`,
`aws-ha-web-stack-tflock`) and to `us-east-1`. After cloning the repo you create
two customer-managed policies and one role in the IAM console, pasting in the JSON
documents from [`iam/`](iam/):

| File | Becomes | Purpose |
|------|---------|---------|
| `iam/deployer-policy.json` | policy `aws-ha-web-stack-deployer-policy` | EC2/VPC, Auto Scaling, ELB, RDS, CloudWatch/Logs, KMS, Secrets Manager — all restricted to `us-east-1`; IAM scoped to `aws-ha-web-stack-*` roles/profiles |
| `iam/backend-policy.json` | policy `aws-ha-web-stack-backend-policy` | S3 + DynamoDB scoped to the `aws-ha-web-stack-tfstate-*` buckets and `aws-ha-web-stack-tflock` lock table |
| `iam/trust-policy.json` | trust policy on role `aws-ha-web-stack-deployer` | Lets your identity assume the role (replace `ACCOUNT_ID`) |

> Deploying to a different region? Change `us-east-1` in `iam/deployer-policy.json`
> before pasting. Renamed `project_name` or the state bucket/lock? Update the
> `aws-ha-web-stack-*` / `aws-ha-web-stack-tfstate-*` / `aws-ha-web-stack-tflock`
> patterns to match.

### a. Create the two policies (IAM Console)

1. Sign in to the **AWS Console → IAM → Policies → Create policy**.
2. Click the **JSON** tab. Open `iam/deployer-policy.json` from your clone, copy
   its **entire** contents, and paste — replacing everything in the editor.
3. **Next**, name it `aws-ha-web-stack-deployer-policy`, **Create policy**.
4. Repeat steps 1–3 with `iam/backend-policy.json`, naming it
   `aws-ha-web-stack-backend-policy`.

**Prefer the CLI?** From the repo root, create both policies with
`aws iam create-policy`. The `file://` prefix is required — without it the CLI
treats the argument as the literal document and fails with
`MalformedPolicyDocument: Syntax errors in policy`:

```bash
aws iam create-policy \
  --policy-name aws-ha-web-stack-deployer-policy \
  --policy-document file://iam/deployer-policy.json

aws iam create-policy \
  --policy-name aws-ha-web-stack-backend-policy \
  --policy-document file://iam/backend-policy.json
```

(Run from inside `iam/`? Drop the directory: `file://deployer-policy.json`. To
push later edits, use `aws iam create-policy-version --set-as-default` instead.)

### b. Create the deployer role (IAM Console)

1. **IAM → Roles → Create role**.
2. Trusted entity type: **Custom trust policy**. Paste the contents of
   `iam/trust-policy.json`, replacing `ACCOUNT_ID` with your 12-digit account ID
   (shown under your name, top-right of the console). **Next**.
3. On **Add permissions**, search for and tick both
   `aws-ha-web-stack-deployer-policy` and `aws-ha-web-stack-backend-policy`. **Next**.
4. Role name: `aws-ha-web-stack-deployer`. **Create role**.

**Prefer the CLI?** Same `file://` pattern as the policies, but the role takes the
trust document on creation and the permissions are *attached* afterwards. First
substitute your account ID into the trust policy (`file://` won't edit the
`ACCOUNT_ID` placeholder for you):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed "s/ACCOUNT_ID/$ACCOUNT_ID/" iam/trust-policy.json > /tmp/trust.json

aws iam create-role \
  --role-name aws-ha-web-stack-deployer \
  --assume-role-policy-document file:///tmp/trust.json

aws iam attach-role-policy --role-name aws-ha-web-stack-deployer \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/aws-ha-web-stack-deployer-policy
aws iam attach-role-policy --role-name aws-ha-web-stack-deployer \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/aws-ha-web-stack-backend-policy
```

(Note the triple slash: `file://` + the absolute path `/tmp/trust.json`.)

### c. Use the role locally for Terraform

Terraform runs from your machine, so it still needs local credentials that assume
the role. Append to `~/.aws/config` (replace `ACCOUNT_ID`; `source_profile` is an
existing local identity allowed to assume the role):

```ini
[profile aws-ha-web-stack-deployer]
role_arn       = arn:aws:iam::ACCOUNT_ID:role/aws-ha-web-stack-deployer
source_profile = default
region         = us-east-1
```

Select it and verify:

```bash
export AWS_PROFILE=aws-ha-web-stack-deployer
aws sts get-caller-identity   # ARN should show assumed-role/aws-ha-web-stack-deployer/...
```

> Prefer not to assume a role locally? In the console create an **IAM user**
> instead, attach the same two policies, generate an access key, then
> `aws configure --profile aws-ha-web-stack-deployer`. Either way, make sure
> `aws sts get-caller-identity` succeeds before continuing.

## 2. Bootstrap remote state (one-time per region)

Creates the S3 bucket + DynamoDB lock table that hold Terraform state.

```bash
cd bootstrap
terraform init
terraform apply \
  -var="aws_region=us-east-1" \
  -var="state_bucket_name=aws-ha-web-stack-tfstate-<unique-suffix>"
cd ..
```

Note the `state_bucket` and `lock_table` outputs.

## 3. Initialize the backend

Point Terraform at the bucket from step 2 (region must match):

```bash
terraform init -reconfigure \
  -backend-config="bucket=aws-ha-web-stack-tfstate-<unique-suffix>" \
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
