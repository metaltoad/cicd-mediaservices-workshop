# Pipeline module

resource "aws_codecommit_repository" "repo" {
  repository_name = "workshop-repo"
  description     = "CodeCommit repository for the workshop"
}

resource "aws_iam_user" "codecommit_user" {
  name = "workshop-codecommit-user"
}

resource "aws_iam_user_policy_attachment" "codecommit_access" {
  user       = aws_iam_user.codecommit_user.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitPowerUser"
}

resource "aws_iam_role" "pipeline_role" {
  name = "workshop-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "pipeline_policy" {
  role = aws_iam_role.pipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ]
        Effect   = "Allow"
        Resource = aws_codecommit_repository.repo.arn
      },
      {
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_codepipeline" "pipeline" {
  name     = "workshop-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.repo.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
      }
    }
  }
}

resource "aws_codebuild_project" "terraform_build" {
  name         = "workshop-build-project"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODEPIPELINE"
    buildspec = yamlencode({
      version: 0.2,
      phases: {
        install: {
          commands: [
            "yum install -y yum-utils",
            "yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo",
            "yum -y install terraform"
          ]
        },
        build: {
          commands: [
            "terraform init",
            "terraform plan",
            "terraform apply -auto-approve"
          ]
        }
      }
    })
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "workshop-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.codebuild_role.name
}

resource "aws_s3_bucket" "artifact_store" {
  bucket = "codepipeline-artifact-store-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "artifact_store" {
  bucket = aws_s3_bucket.artifact_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "codecommit_repo_url" {
  value = aws_codecommit_repository.repo.clone_url_http
}

output "pipeline_name" {
  value = aws_codepipeline.pipeline.name
}