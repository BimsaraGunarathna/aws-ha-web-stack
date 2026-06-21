# Negative tests: confirm the input validations reject bad values.
# `expect_failures` asserts the named object fails its validation during plan.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"] }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-0mockmockmock0000" }
  }
  mock_data "aws_region" {
    defaults = { name = "eu-central-1" }
  }
}

variables {
  db_password = "testpw12"
}

run "rejects_single_az" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_short_db_password" {
  command = plan

  variables {
    db_password = "short"
  }

  expect_failures = [var.db_password]
}
