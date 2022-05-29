#terraform init
#terraform plan -var "repo_id=zacherytcox/hello-beautiful" -var "git_branch=main" -var "git_commit=$(git show --oneline -s | head -n1 | cut -d " " -f1)" 
#terraform apply -var "repo_id=zacherytcox/hello-beautiful" -var "git_branch=main" -var "git_commit=$(git show --oneline -s | head -n1 | cut -d " " -f1)" 

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

variable "repo_id" {
  type = string
}

variable "git_branch" {
  type = string
}

variable "git_commit" {
  type = string
}

variable "stack_name" {
  type = string
}



resource "aws_s3_bucket" "bucket" {
  tags = {
    RepoID    = var.repo_id
    GitBranch = var.git_branch
    GitCommit = var.git_commit
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_codepipeline" "codepipeline" {
  role_arn = aws_iam_role.iam_role_pipeline.arn
  name     = "Hello-Beautiful-Pipieline"

  artifact_store {
    location = aws_s3_bucket.bucket.bucket
    type     = "S3"
  }

  # Source
  stage {
    name = "Source"

    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeStarSourceConnection"
      version  = "1"

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.codestar_connection.arn
        FullRepositoryId = var.repo_id
        BranchName       = var.git_branch
      }
      namespace        = "SourceVariables"
      output_artifacts = ["SourceOutput"]
    }
  }

  #Pre-Deploy_Checks TODO
  # stage {
  #   name = "Deploy"

  #   action {
  #     name            = "Deploy"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "CloudFormation"
  #     input_artifacts = ["build_output"]
  #     version         = "1"

  #     configuration = {
  #       ActionMode     = "REPLACE_ON_FAILURE"
  #       Capabilities   = "CAPABILITY_AUTO_EXPAND,CAPABILITY_IAM"
  #       OutputFileName = "CreateStackOutput.json"
  #       StackName      = "MyStack"
  #       TemplatePath   = "build_output::sam-templated.yaml"
  #     }
  #   }
  # }

  #Deploy-Stage
  stage {
    name = "Deploy-Stage"

    action {

      name            = "Deploy-Stage"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["SourceOutput"]
      version         = "1"

      configuration = {
        ActionMode     = "CREATE_UPDATE"
        OutputFileName = "CreateStackOutput.json"
        StackName      = "${var.stack_name}-App-Stage"
        TemplatePath   = "SourceOutput::app/app.yaml"
        RoleArn = aws_iam_role.iam_role_cloudformation.arn

        # May be problematic...
        ParameterOverrides : "{\"GitCommit\": \"${var.git_commit}\",\"GitBranch\": \"${var.git_branch}\",\"RepoID\": \"${var.repo_id}\"}"
      }
    }
  }

  # Data-Test-Stage
  stage {
    name = "Data-Test-Stage"

    action {
      name            = "Test-Stage"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceOutput"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.codebuild_stage.name
      }
    }
  }

  # stage {
  #   name = "Deploy"

  #   action {
  #     name            = "Deploy"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "CloudFormation"
  #     input_artifacts = ["build_output"]
  #     version         = "1"

  #     configuration = {
  #       ActionMode     = "REPLACE_ON_FAILURE"
  #       Capabilities   = "CAPABILITY_AUTO_EXPAND,CAPABILITY_IAM"
  #       OutputFileName = "CreateStackOutput.json"
  #       StackName      = "MyStack"
  #       TemplatePath   = "build_output::sam-templated.yaml"
  #     }
  #   }
  # }

  # stage {
  #   name = "Deploy"

  #   action {
  #     name            = "Deploy"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "CloudFormation"
  #     input_artifacts = ["build_output"]
  #     version         = "1"

  #     configuration = {
  #       ActionMode     = "REPLACE_ON_FAILURE"
  #       Capabilities   = "CAPABILITY_AUTO_EXPAND,CAPABILITY_IAM"
  #       OutputFileName = "CreateStackOutput.json"
  #       StackName      = "MyStack"
  #       TemplatePath   = "build_output::sam-templated.yaml"
  #     }
  #   }
  # }
}

resource "aws_iam_role" "iam_role_pipeline" {

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["*"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}

resource "aws_iam_role" "iam_role_codebuild" {

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Effect   = "Allow"
          Resource = "arn:aws:logs:*:*:log-group:*"
        },
        {
          Action   = ["s3:DeleteBucket","s3:DeleteBucketPolicy","s3:ListBucket"]
          Effect   = "Allow"
          Resource = "arn:aws:s3:::${lower(var.stack_name)}*"
        },
        {
          Action   = ["s3:GetObject","s3:DeleteObject","s3:PutObject"]
          Effect   = "Allow"
          Resource = ["${aws_s3_bucket.bucket.arn}*/*"]#,"arn:aws:s3:::${var.stack_name}*/*"]
        },
        {
          Action   = ["cloudformation:DescribeStacks"]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = ["cloudformation:DeleteStack","cloudformation:DescribeStackResources"]
          Effect   = "Allow"
          Resource = "arn:aws:cloudformation:us-east-1:${data.aws_caller_identity.current.account_id}:stack/${var.stack_name}-*"
        }
        
      ]
    })
  }
}

resource "aws_iam_role" "iam_role_cloudformation" {

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:CreateBucket", "s3:GetBucketPolicy", "s3:PutBucketPolicy", "s3:PutBucketTagging", "s3:PutBucketWebsite"]
          Effect   = "Allow"
          Resource = "arn:aws:s3:::*"
        }
      ]
    })
  }
}

resource "aws_codestarconnections_connection" "codestar_connection" {
  name          = "hello-beautiful"
  provider_type = "GitHub"
}

resource "aws_codebuild_project" "codebuild_stage" {
  name         = "codebuild_stage"
  service_role = aws_iam_role.iam_role_codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type              = "CODEPIPELINE"
    # source_identifier = pleaseworkforZach
    buildspec         = file("${path.module}/buildspecs/buildspecstage.yaml")
  }
}
