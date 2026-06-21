# Pick the first N available AZs in the region so the config is region-portable.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.project_name}-igw" })
}

# Public subnets host the ALB and the NAT gateway. One per AZ.
#trivy:ignore:AWS-0164 -- Public subnets require public IPs for the ALB and NAT gateway.
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name           = "${var.project_name}-public-${local.azs[count.index]}"
    "checkov:skip" = "CKV_AWS_130:Public subnets require public IPs for the ALB and NAT gateway"
  })
}

# Private subnets host the app instances and the database. One per AZ.
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 100)
  availability_zone = local.azs[count.index]
  tags              = merge(var.tags, { Name = "${var.project_name}-private-${local.azs[count.index]}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Single NAT gateway gives private instances outbound internet (e.g. to install nginx).
# Cost/HA tradeoff: one NAT is cheaper but is a single-AZ dependency. For production,
# deploy one NAT per AZ. Documented in the README.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.project_name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = "${var.project_name}-nat" })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.project_name}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_caller_identity" "current" {}

# ---- VPC Flow Logs -----------------------------------------------------------
# Captures IP traffic metadata for security auditing and troubleshooting.
resource "aws_kms_key" "flow_logs" {
  count                   = var.enable_vpc_flow_logs ? 1 : 0
  description             = "KMS key for VPC Flow Logs encryption."
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
}

resource "aws_kms_key_policy" "flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  key_id = aws_kms_key.flow_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "flow_logs" {
  count         = var.enable_vpc_flow_logs ? 1 : 0
  name          = "alias/${var.project_name}-flow-logs-key"
  target_key_id = aws_kms_key.flow_logs[0].key_id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_vpc_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.flow_logs[0].arn
  tags              = var.tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-flow-logs-policy"
  role  = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count                    = var.enable_vpc_flow_logs ? 1 : 0
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  max_aggregation_interval = 600

  tags = merge(var.tags, { Name = "${var.project_name}-flow-log" })
}
