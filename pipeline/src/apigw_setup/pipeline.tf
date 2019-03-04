resource "aws_s3_bucket" "artifacts" {
  bucket = "prm-${data.aws_caller_identity.current.account_id}-apigw-setup-pipeline-artifacts-${var.environment}"
  acl    = "private"
}

# Role to use for running pipeline
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipeline_role" {
  name               = "prm-apigw-setup-pipeline-${var.environment}"
  assume_role_policy = "${data.aws_iam_policy_document.codepipeline_assume.json}"
}

data "aws_iam_policy_document" "pipeline_role_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]

    resources = ["${aws_s3_bucket.artifacts.arn}"]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = [
      "${aws_codebuild_project.terratest.arn}",
      "${aws_codebuild_project.deploy.arn}",
    ]
  }
}

resource "aws_iam_role_policy" "pipeline_role_policy" {
  name   = "prm-apigw-setup-pipeline"
  role   = "${aws_iam_role.pipeline_role.id}"
  policy = "${data.aws_iam_policy_document.pipeline_role_policy.json}"
}

# Pipeline
data "aws_ssm_parameter" "github_token" {
  name = "${var.github_token_name}"
}

resource "aws_codepipeline" "pipeline" {
  name     = "prm-apigw-setup-${var.environment}"
  role_arn = "${aws_iam_role.pipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.artifacts.bucket}"
    type     = "S3"
  }

  stage {
    name = "source"

    action {
      name             = "source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration {
        Owner      = "subnova-nhs"
        Repo       = "prm-apigw-setup"
        Branch     = "master"
        OAuthToken = "${data.aws_ssm_parameter.github_token.value}"
      }
    }
  }

  stage {
    name = "terratest"

    action {
      name            = "terratest"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]
      run_order       = 1

      configuration {
        ProjectName = "${aws_codebuild_project.terratest.name}"
        PrimarySource = "source"
      }
    }
  }

  stage {
    name = "deploy"

    action {
      name            = "deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]

      configuration {
        ProjectName = "${aws_codebuild_project.deploy.name}"
        PrimarySource = "source"
      }
    }
  }
}

