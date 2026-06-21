# Scalable Web Application Infrastructure (Terraform / AWS)

Terraform configuration that provisions a highly available, auto-scaling Nginx web
tier behind an Application Load Balancer, with a managed PostgreSQL (RDS) database,
strict tiered security groups, remote state, and CloudWatch monitoring.

## Architecture

```
                    Internet
                       │  HTTP :80   (or HTTPS :443 with :80 → 301 when enable_https=true)
                ┌──────▼──────┐
                │     ALB     │   public subnets (2 AZs)
                │  (alb-sg)   │
                └──────┬──────┘
            ┌──────────┴──────────┐
       ┌────▼────┐           ┌────▼────┐
       │  EC2    │           │  EC2    │   private subnets (2 AZs)
       │ Nginx   │   ...     │ Nginx   │   Auto Scaling Group (2–4)
       │(inst-sg)│           │(inst-sg)│   instance-sg: :80 from ALB only
       └────┬────┘           └────┬────┘
            └──────────┬──────────┘
                  ┌────▼────┐
                  │   RDS   │   private subnets
                  │Postgres │   db-sg: :5432 from instances only
                  └─────────┘
```

By default the ALB serves the app over plain HTTP on :80 (zero-friction demo, no
certificate needed). Set `enable_https = true` to serve HTTPS on :443 with :80
redirecting to it — see step 3 below.

**Security model** — traffic flows strictly `internet → ALB → instances → DB`.
Each tier's security group only accepts traffic from the tier directly in front of it:
the ALB takes :80 and :443 from anywhere, instances take :80 *only* from the ALB's SG, and the
database takes :5432 *only* from the instances' SG. Instances and the database live in
private subnets with no public IPs; outbound internet (for package installs) goes
through a NAT gateway.

## Module layout

| Module | Responsibility |
|--------|----------------|
| `modules/network`  | VPC, public/private subnets across 2 AZs, IGW, NAT gateway, route tables |
| `modules/security` | The three tiered security groups (ALB, instance, database) |
| `modules/compute`  | ALB + target group + listeners, IAM instance profile (SSM + CloudWatch), launch template, Auto Scaling Group, target-tracking scaling policy, CloudWatch alarm + dashboard |
| `modules/database` | RDS subnet group + managed PostgreSQL/MySQL instance, KMS key, auto-generated password in Secrets Manager |

The root module (`main.tf`) wires the modules together; `variables.tf`, `outputs.tf`,
`providers.tf`, `versions.tf`, and `backend.tf` configure the rest.

Each module also exposes **test-support outputs** (e.g. `autoscaling_group`, `load_balancer`,
`db_instance`, `alb_security_group`) so that the offline `terraform test` suite can assert
on internal resource properties without needing direct resource access.

## Requirements covered

1. Terraform provisions everything ✔
2. ASG with ≥2 instances (`min_size`/`desired_capacity` default to 2) ✔
3. ALB distributes traffic across the ASG ✔
4. Managed database (RDS PostgreSQL) ✔
5. Security rules — ALB :80 HTTP (optionally :443 HTTPS with :80 → :443 redirect), instances :80 from ALB only, DB from instances only ✔
6. Variables + modules throughout ✔
7. `outputs.tf` exposes the load balancer URL, DB endpoint, ASG name, dashboard, VPC ✔
8. Remote state in S3 with native lockfile locking (`backend.tf` + `bootstrap/`) ✔
9. This README ✔

**Bonus:** CloudWatch alarm + dashboard ✔ · modules, variable files, workspace-ready ✔ · Nginx welcome page via user data ✔ · DB password auto-generated and stored in AWS Secrets Manager ✔

## Prerequisites

- Terraform >= 1.10 (the S3 backend uses native `use_lockfile` locking)
- AWS credentials configured (`aws configure` or env vars) with permission to create
  VPC/EC2/ELB/RDS/IAM/CloudWatch/S3 resources
- An AWS account (note: this deploys billable resources — see **Cost**)

## Deploy

### 1. Bootstrap the remote state backend (one time)

The S3 bucket must exist before the main config can use it (state locking uses a
`.tflock` object in the same bucket — no DynamoDB table required).

```bash
cd bootstrap
terraform init
terraform apply -var="state_bucket_name=<your-globally-unique-bucket>"
```

Note the `state_bucket` output.

### 2. Point the root module at that backend

Edit `backend.tf` and set `bucket` (and `region` if you changed it),
**or** pass it at init time:

```bash
cd ..
terraform init -backend-config="bucket=<your-globally-unique-bucket>"
```

### 3. (Optional) Enable HTTPS

By default the ALB serves the app over **plain HTTP on port 80** — no certificate
required, so `apply` works out of the box. To serve HTTPS instead (ALB listens on
:443 and redirects :80 → :443), set `enable_https = true` and supply an ACM
certificate in the target region:

```bash
export TF_VAR_enable_https=true
export TF_VAR_acm_certificate_arn='arn:aws:acm:...'
```

### 4. Plan and apply

```bash
terraform plan  -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### 5. Visit the app

```bash
terraform output load_balancer_url
```

Open the URL; refresh a few times to watch the ALB rotate between instances (the page
prints the serving instance ID and AZ). RDS takes several minutes to come up.

### 6. Tear down (avoid ongoing charges)

> **Note:** RDS deletion protection is enabled by default (`db_deletion_protection = true`).
> `terraform destroy` will fail while it is on, so first disable it with an apply, then destroy:

```bash
terraform apply   -var-file="environments/dev.tfvars" -var="db_deletion_protection=false"
terraform destroy -var-file="environments/dev.tfvars" -var="db_deletion_protection=false"
# then, if you no longer need remote state:
cd bootstrap && terraform destroy -var="state_bucket_name=<your-bucket>"
```

## Environments / workspaces

Per-environment sizing lives in `environments/dev.tfvars` and `environments/prod.tfvars`.
To isolate state per environment with workspaces:

```bash
terraform workspace new prod
terraform workspace select prod
terraform apply -var-file="environments/prod.tfvars"
```

## Key variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `aws_region` | `eu-central-1` | Region to deploy into |
| `az_count` | `2` | Number of AZs to spread across (min 2) |
| `enable_vpc_flow_logs` | `true` | Capture VPC flow logs to CloudWatch (KMS-encrypted) |
| `instance_type` | `t3.micro` | App instance size |
| `min_size` / `max_size` / `desired_capacity` | `2` / `4` / `2` | ASG bounds |
| `cpu_target` | `50` | ASG target-tracking CPU % |
| `enable_https` | `false` | Serve HTTPS on :443 (:80 redirects). When off, ALB serves plain HTTP on :80 |
| `acm_certificate_arn` | `""` | ACM cert ARN for ALB HTTPS — required only when `enable_https = true` |
| `db_engine` | `postgres` | `postgres` (5432) or `mysql` (3306) |
| `db_engine_version` | `16` | RDS engine version |
| `db_instance_class` | `db.t3.micro` | RDS size |
| `db_allocated_storage` | `20` | RDS storage (GB) |
| `db_multi_az` | `false` | RDS standby in a 2nd AZ |
| `db_skip_final_snapshot` | `true` | Skip final snapshot on delete |
| `db_deletion_protection` | `true` | Block accidental RDS deletion — set `false` to allow `terraform destroy` |
| `db_backup_retention_period` | `7` | Days to retain automated RDS backups |

## Cost note

This is **not** entirely free-tier. The NAT gateway, ALB, and RDS each bill hourly.
Expect a few USD if you leave it running for a day; `terraform destroy` when done.

## Production hardening

These are deliberate demo trade-offs — worth calling out rather than hiding:

- **NAT HA:** one NAT gateway is a single-AZ dependency. Production uses one per AZ.
- **RDS:** `skip_final_snapshot = true` makes teardown easy but is unsafe for real data;
  set it to `false` for production, and enable `multi_az`. Deletion protection is already
  enabled by default.
- **State:** real setups separate state per environment and lock down the bucket policy.
- **HTTPS/ACM:** the demo defaults to plain HTTP on :80 for zero-friction setup.
  Production should set `enable_https = true` with an ACM certificate; cert provisioning
  and DNS validation are best automated via Route 53.

## Testing & quality gates

The repo ships with a reproducible toolbox container and a test suite, so the
whole thing can be verified with one command and no AWS account.

### What runs

| Gate | Tool | Cost |
|------|------|------|
| Formatting | `terraform fmt -check` | free |
| Validation | `terraform validate` | free |
| Linting | `tflint` + AWS ruleset | free |
| Unit tests | `terraform test` (mocked provider) | free, offline |
| Security scan | `trivy config` + `checkov` | free |

The **unit tests** (`tests/*.tftest.hcl`) use a `mock_provider`, so they run at
`plan` level with no credentials and no billed resources. They assert the things
that actually matter for this task:

- the three-tier security model — ALB open on 80 and 443, instances reachable *only* via
  a security group (never a public CIDR), database reachable *only* from instances;
- the ASG has ≥2 instances with ELB health checks;
- the ALB is an internet-facing application LB on port 80;
- RDS is private and encrypted;
- the input validations reject bad values (single AZ, unknown environment).

Because `terraform test` cannot reference module-internal resources directly, the tests
rely on the **test-support outputs** each module exposes to verify resource properties.

### Run it locally

One command, from the repo root:

```bash
./validate.sh
```

It auto-detects your setup:

- **If Terraform (>=1.10) is on your PATH**, it runs directly. tflint / trivy /
  checkov are used if installed and politely skipped if not — so the core gates
  (fmt, validate, `terraform test`) work with nothing but Terraform.
- **If Terraform isn't installed but Docker is**, it builds the pinned container
  and runs the *full* toolchain against your live files (bind-mounted, as your
  own user so it leaves no root-owned `.terraform/` behind).

Prerequisites, minimal to maximal:

| You have | What runs |
|----------|-----------|
| Docker only | Everything (Terraform + tflint + trivy + checkov), pinned versions |
| Terraform only | fmt, validate, `terraform test` (the hard gates) |
| Terraform + the lint/security tools | Everything, using your local versions |

Equivalent Make targets if you prefer:

```bash
make check        # fmt-check + validate + lint + test  (local toolchain)
make security     # trivy + checkov
make docker-check # full suite in the container, against your live tree
make help         # list all targets
```

Nothing here touches AWS or costs money — `terraform init` runs with
`-backend=false` and the tests mock the provider, so no credentials are needed to
validate.

### A note on the security scanners

trivy and checkov flag the **intentional** demo trade-offs (public ALB ingress,
unrestricted instance egress for package installs, RDS teardown convenience).
Rather than blanket-disable the scanners, those specific checks are listed with
justifications in `.checkov.yaml` and `.trivyignore` — and all of them are the
same items in *Production hardening* above. Set `STRICT_SECURITY=1` to make the
scans gate the build.

### Validate before submitting

Run the suite before you send it:

```bash
./validate.sh
```

A clean run ends with `done. Hard gates passed.` If anything fails, the error
points at the exact file/line — fix and re-run.
