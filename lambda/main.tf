resource "aws_iam_role" "default" {
  name = "${local.lambda_function_name}-${var.environment}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = ["sts:AssumeRole"]
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow"
        Sid    = local.sid
      },
    ]
  })

  inline_policy {
    name = "cloudwatch-access"

    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          Effect = "Allow",
          Resource = "arn:aws:logs:*:*:${local.lambda_function_name}-${var.environment}"
        }
      ]
    })
  }

  dynamic "inline_policy" {
    for_each = length(var.kms_arns) != 0 ? [1] : []
    content {
      name   = "kms-access"
      policy = jsonencode({
        Version   = "2012-10-17"
        Statement = [
          {
            Action = [
              "kms:Decrypt",
              "kms:GenerateDataKey"
            ]
            Effect   = "Allow"
            Resource = var.kms_arns
          }
        ]
      })
    }
  }

  dynamic "inline_policy" {
    for_each = length(var.dynamodb_arns) != 0 ? [1] : []
    content {
      name = "dynamodb-access"

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action = [
              "dynamodb:PutItem",
              "dynamodb:GetItem",
              "dynamodb:ListTables"
            ]
            Effect   = "Allow"
            Resource = var.dynamodb_arns
          },
        ]
      })
    }
  }

  dynamic "inline_policy" {
    for_each = length(var.dead_letter_arns) != 0 ? [1] : []
    content {
      name = "sqs-access"

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action = "sqs:*"
            Effect   = "Allow"
            Resource = var.dead_letter_arns
          },
        ]
      })
    }
  }

  dynamic "inline_policy" {
    for_each = length(var.config_secret_arns) != 0 ? [1] : []
    content {
      name = "secret-access"

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action = [
              "secretsmanager:ListSecrets",
              "secretsmanager:GetSecretValue"
            ]
            Effect   = "Allow"
            Resource = var.config_secret_arns
          },
        ]
      })
    }
  }
}

data "archive_file" "default" {
  type             = "zip"
  source_dir      = local.lambda_input_path
  output_file_mode = "0666"
  output_path      = local.lambda_output_path
}

resource "aws_lambda_function" "default" {
  filename      = local.lambda_output_path
  function_name = "${local.lambda_function_name}-${var.environment}"
  role          = aws_iam_role.default.arn
  handler       = var.lambda_handler
  timeout       = var.lambda_timeout

  source_code_hash = filebase64sha256(local.lambda_output_path)

  runtime = var.lambda_runtime

  environment {
    variables = var.lambda_env_variables
  }

  dynamic "dead_letter_config" {
    for_each = toset(var.dead_letter_arns)
    content {
      target_arn = dead_letter_config.value
    }
  }

  tags = {
    Environment = var.environment
    Name        = local.lambda_function_name
  }
}