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

- Terraform >= 1.10 and the AWS CLI installed
- A clone of this repo (the `iam/*.json` policy documents are used in step 1)
- An AWS account with Console access to IAM (to create the policies and role)

## 1. Create the scoped deployer role and base user

No admin access. The stack creates IAM roles, KMS keys, and Secrets Manager
secrets, so the deployer needs those permissions — but scoped to this project's
resources (`aws-ha-web-stack-*`, `aws-ha-web-stack-tfstate-*`) and to
`us-east-1`. After cloning the repo you create the customer-managed policies, the
deployer role, and a thin base user that can assume it — pasting in the JSON
documents from [`iam/`](iam/):

| File | Becomes | Purpose |
|------|---------|---------|
| `iam/deployer-policy.json` | policy `aws-ha-web-stack-deployer-policy` | EC2/VPC, Auto Scaling, ELB, RDS, CloudWatch/Logs, KMS, Secrets Manager — all restricted to `us-east-1`; IAM scoped to `aws-ha-web-stack-*` roles/profiles |
| `iam/backend-policy.json` | policy `aws-ha-web-stack-backend-policy` | S3 scoped to the `aws-ha-web-stack-tfstate-*` buckets (holds both the state file and its `.tflock` lock object) |
| `iam/trust-policy.json` | trust policy on role `aws-ha-web-stack-deployer` | Lets your account's identities assume the role (replace `ACCOUNT_ID`) |
| `iam/assume-deployer-policy.json` | policy `aws-ha-web-stack-assume-deployer` | Lets the base user assume the deployer role — its only permission |

The base user holds no standing permissions: it can do nothing except assume the
deployer role, and the role is where the scoped access lives. Long-lived access
keys therefore grant nothing on their own.

> Deploying to a different region? Change `us-east-1` in `iam/deployer-policy.json`
> before pasting. Renamed `project_name` or the state bucket? Update the
> `aws-ha-web-stack-*` / `aws-ha-web-stack-tfstate-*` patterns to match.

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

### c. Create the base user that assumes the role (IAM Console)

The role can't authenticate by itself — something has to assume it. Create a
dedicated user whose *only* permission is to assume the deployer role.

1. **IAM → Policies → Create policy → JSON**, paste `iam/assume-deployer-policy.json`,
   name it `aws-ha-web-stack-assume-deployer`, **Create policy**.
2. **IAM → Users → Create user**, name it `aws-ha-web-stack-cli`. Do **not** give
   it console access.
3. On **Set permissions → Attach policies directly**, tick
   `aws-ha-web-stack-assume-deployer`. **Create user**.
4. Open the user → **Security credentials → Create access key** → use case
   **Command Line Interface (CLI)**. Copy the **Access key ID** and **Secret**.

**Prefer the CLI?**

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-policy --policy-name aws-ha-web-stack-assume-deployer \
  --policy-document file://iam/assume-deployer-policy.json

aws iam create-user --user-name aws-ha-web-stack-cli
aws iam attach-user-policy --user-name aws-ha-web-stack-cli \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/aws-ha-web-stack-assume-deployer

aws iam create-access-key --user-name aws-ha-web-stack-cli   # note the key + secret
```

### d. Wire up the two local profiles and verify

The base user holds the access keys; the deployer profile assumes the role using
them. Configure the base user, then add the role profile.

```bash
# Base user credentials (writes to ~/.aws/credentials).
aws configure --profile aws-ha-web-stack-cli
# AWS Access Key ID     : <from step c>
# AWS Secret Access Key : <from step c>
# Default region name   : us-east-1
# Default output format  : json
```

Append the role profile to `~/.aws/config` (replace `ACCOUNT_ID`; `source_profile`
points at the base user you just configured):

```ini
[profile aws-ha-web-stack-deployer]
role_arn       = arn:aws:iam::ACCOUNT_ID:role/aws-ha-web-stack-deployer
source_profile = aws-ha-web-stack-cli
region         = us-east-1
```

Select the deployer profile and verify it resolves to the assumed role:

```bash
export AWS_PROFILE=aws-ha-web-stack-deployer
aws sts get-caller-identity   # ARN should show assumed-role/aws-ha-web-stack-deployer/...
```

> Already authenticate via SSO or an existing admin user? Skip the base user and
> point `source_profile` at that identity instead — just make sure
> `aws sts get-caller-identity` succeeds before continuing.

## 2. Bootstrap remote state (one-time per region)

Creates the S3 bucket that holds Terraform state (locking uses a `.tflock` object
in the same bucket — no DynamoDB needed).

```bash
cd bootstrap
terraform init
terraform apply \
  -var="aws_region=us-east-1" \
  -var="state_bucket_name=aws-ha-web-stack-tfstate-<unique-suffix>"
cd ..
```

Note the `state_bucket` output.

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

> Bootstrap resources (the state bucket) are kept separately and are not removed
> by this destroy. Delete them manually only if you no longer need the state.

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
