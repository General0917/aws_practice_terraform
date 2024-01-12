module "ecs" {
  source = "./ecs"
}

# ECRリポジトリの定義
resource "aws_ecr_repository" "example" {
  name = "example"
}

# ECRライフサイクルポリシーの定義
resource "aws_ecr_lifecycle_policy" "example" {
  repository = aws_ecr_repository.example.name

  policy = <<EOF
  {
    "rules" : [
        {
            "rulePriority" :1,
            "description" : "Keep last 30 release tagged images",
            "selection" : {
                "tagStatus" : "tagged",
                "tagPrefixList" : ["release"],
                "countType" : "imageCountMoreThan",
                "countNumber" : 30
            },
            "action" : {
                "type" : "expire"
            }
        }
    ]
  }
  EOF
}

# CodeBuildサービスロールのポリシードキュメントの定義
data "aws_iam_policy_document" "codebuild" {
  statement {
    effect = "Allow"
    resources = ["*"]

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
  }
}

# CodeBuildサービスロールの定義
module "codebuild_role" {
  source = "./iam_role"
  name = "codebuild"
  identifier = "codebuild.amazonaws.com"
  policy = data.aws_iam_policy_document.codebuild.json
}

# CodeBuildプロジェクトの定義
resource "aws_codebuild_project" "example" {
  name = "example"
  service_role = module.codebuild_role.iam_role_arn

  source {
    type = "CODEPIPELINE"
    location = "aws_practice_terraform"
    git_clone_depth = 1
    buildspec = "./buildspec.yaml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/standard:2.0"
    privileged_mode = true
  }
}

# CodePipelineサービスロールのポリシードキュメントの定義
data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect = "Allow"
    resources = ["*"]

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "iam:PassRole",
    ]
  }
}

# CodePipelineサービスロールの定義
module "codepipeline_role" {
  source = "./iam_role"
  name = "codepipeline"
  identifier = "codepipeline.amazonaws.com"
  policy = data.aws_iam_policy_document.codepipeline.json
}

# アーティファクトストアの定義
resource "aws_s3_bucket" "artifact" {
  bucket = "artifact-pragmatic1-terraform"
}

resource "aws_s3_bucket_lifecycle_configuration" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  rule {
    id = "rule-1"
    status = "Enabled"

    expiration {
      days = 180
    }
  }
}

# CodePipelineの定義
resource "aws_ssm_parameter" "secret" {
  name        = "/continuous_apply/github_token"
  description = "The parameter description"
  type        = "String"
  insecure_value = "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"
}

data "aws_ssm_parameter" "github_token" {
  name = aws_ssm_parameter.secret.name
}

resource "aws_codepipeline" "example" {
  name = "example"
  role_arn = module.codepipeline_role.iam_role_arn

  stage {
    name = "Source"

    action {
      name = "Source"
      category = "Source"
      owner = "ThirdParty"
      provider = "GitHub"
      version = 1
      output_artifacts = ["Source"]

      configuration = {
        Owner = "General0917"
        Repo = "aws_practice_terraform"
        Branch = "master"
        PollForSourceChanges = false
        OAuthToken = data.aws_ssm_parameter.github_token.value
      }
    }
  }

  stage {
    name = "Build"

    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = 1
      input_artifacts = ["Source"]
      output_artifacts = ["Build"]

      configuration = {
        ProjectName = aws_codebuild_project.example.id
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name = "Deploy"
      category = "Deploy"
      owner = "AWS"
      provider = "ECS"
      version = 1
      input_artifacts = ["Build"]

      configuration = {
        ClusterName = module.ecs.aws_ecs_cluster_name
        ServiceName = module.ecs.aws_ecs_service_name
        FileName = "imagedefinitions.json"
      }
    }
  }

  artifact_store {
    location = aws_s3_bucket.artifact.id
    type = "S3"
  }
}

# CodePipeline Webhookの定義
resource "random_id" "sample" {
  keepers = {
    codepipeline_name = aws_codepipeline.example.name
  }

  byte_length = 32
}

resource "aws_codepipeline_webhook" "example" {
  name = "example"
  target_pipeline = aws_codepipeline.example.name
  target_action = "Source"
  authentication = "GITHUB_HMAC"

  authentication_configuration {
    secret_token = random_id.sample.hex
  }

  filter {
    json_path = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}

output "random_id_output" {
  value = random_id.sample.hex
}

# GitHubプロバイダの定義
provider "github" {
  owner = "General0917"
  token = "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"
}

# GitHub Webhookの定義
resource "github_repository_webhook" "example" {
  repository = "aws_practice_terraform"

  configuration {
    url = aws_codepipeline_webhook.example.url
    secret = random_id.sample.hex
    content_type = "json"
    insecure_ssl = false
  }

  events = ["push"]
}