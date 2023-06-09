locals {
  secret_name = var.prefix_secret == "" ? var.secret_name : "${var.prefix_secret}-${var.secret_name}"
}

resource "aws_secretsmanager_secret" "this" {
  name = "${local.secret_name}-${var.environment}"
}