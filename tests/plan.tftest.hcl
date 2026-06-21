# Plan-level unit tests using a MOCKED AWS provider.
#
# These run with `terraform test` and never touch a real AWS account: no
# credentials, no cost, fast enough for CI on every push. The mock provider
# supplies deterministic values for the data sources the config reads so that
# computed-at-plan logic (AZ slicing, AMI lookup) still resolves.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    }
  }
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0mockmockmock0000"
    }
  }
  mock_data "aws_region" {
    defaults = {
      name = "eu-central-1"
    }
  }
}

# db_password is required; supply a dummy that satisfies validation.
variables {
  db_password = "testpw12"
}

run "networking_spans_two_azs" {
  command = plan

  assert {
    condition     = length(module.network.public_subnet_ids) == 2
    error_message = "Expected 2 public subnets (one per AZ)."
  }
  assert {
    condition     = length(module.network.private_subnet_ids) == 2
    error_message = "Expected 2 private subnets (one per AZ)."
  }
}

run "asg_has_at_least_two_instances" {
  command = plan

  assert {
    condition     = module.compute.autoscaling_group.min_size == 2
    error_message = "ASG min_size must be 2."
  }
  assert {
    condition     = module.compute.autoscaling_group.desired_capacity == 2
    error_message = "ASG desired_capacity must be 2."
  }
  assert {
    condition     = module.compute.autoscaling_group.max_size == 4
    error_message = "ASG max_size must be 4."
  }
  assert {
    condition     = module.compute.autoscaling_group.health_check_type == "ELB"
    error_message = "ASG should use ELB health checks so the LB can replace bad instances."
  }
  assert {
    condition     = module.compute.target_group.port == 80
    error_message = "Target group must route to port 80."
  }
}

run "load_balancer_is_public_application_lb" {
  command = plan

  assert {
    condition     = module.compute.load_balancer.load_balancer_type == "application"
    error_message = "Load balancer must be an ALB."
  }
  assert {
    condition     = module.compute.load_balancer.internal == false
    error_message = "ALB must be internet-facing."
  }
  assert {
    condition     = module.compute.lb_listener.port == 80
    error_message = "ALB listener must serve HTTP on port 80."
  }
}

run "database_is_private_and_encrypted" {
  command = plan

  assert {
    condition     = module.database.db_instance.engine == "postgres"
    error_message = "Database engine should be postgres."
  }
  assert {
    condition     = module.database.db_instance.publicly_accessible == false
    error_message = "Database must not be publicly accessible."
  }
  assert {
    condition     = module.database.db_instance.storage_encrypted == true
    error_message = "Database storage must be encrypted."
  }
}

# ---- Security model: the heart of the assessment's requirement 5 ----
run "security_tiers_are_chained_not_open" {
  command = plan

  # ALB: HTTP/80 open to the internet.
  assert {
    condition = anytrue([
      for r in module.security.alb_security_group.ingress :
      r.from_port == 80 && contains(r.cidr_blocks, "0.0.0.0/0")
    ])
    error_message = "ALB SG must allow HTTP/80 from 0.0.0.0/0."
  }

  # Instances: port 80 present but NOT open to any CIDR (locked to the ALB SG).
  assert {
    condition = anytrue([
      for r in module.security.instance_security_group.ingress :
      r.from_port == 80 && length(coalesce(r.cidr_blocks, [])) == 0
    ])
    error_message = "Instance SG must allow 80 only from a security group, not a CIDR."
  }
  assert {
    condition = alltrue([
      for r in module.security.instance_security_group.ingress :
      !contains(coalesce(r.cidr_blocks, []), "0.0.0.0/0")
    ])
    error_message = "Instance SG must never be open to the internet."
  }

  # Database: DB port present but NOT open to any CIDR (locked to the instance SG).
  assert {
    condition = anytrue([
      for r in module.security.database_security_group.ingress :
      r.from_port == 5432 && length(coalesce(r.cidr_blocks, [])) == 0
    ])
    error_message = "DB SG must allow 5432 only from a security group, not a CIDR."
  }
  assert {
    condition = alltrue([
      for r in module.security.database_security_group.ingress :
      !contains(coalesce(r.cidr_blocks, []), "0.0.0.0/0")
    ])
    error_message = "DB SG must never be open to the internet."
  }
}

run "outputs_are_wired" {
  command = plan

  # database_name is known at plan time (derived from a variable), so we can
  # assert the output is plumbed through correctly.
  assert {
    condition     = output.database_name == "appdb"
    error_message = "database_name output should expose the configured DB name."
  }
}
