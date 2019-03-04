resource "aws_api_gateway_rest_api" "api_gw_endpoint" {
  name        = "ehr-translate-${var.environment}"
  description = "API to allow EHR summary records to be translated from v2.2 to 3.0"
}

data "aws_iam_policy_document" "apigateway_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_gw_role" {
  name               = "ehr-translate-${var.environment}-api-gw"
  assume_role_policy = "${data.aws_iam_policy_document.apigateway_assume.json}"
}

data "aws_iam_policy_document" "apigateway_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_gw_role_policy" {
  role   = "${aws_iam_role.api_gw_role.id}"
  policy = "${data.aws_iam_policy_document.apigateway_policy.json}"
}

resource "aws_api_gateway_account" "api_gw_account" {
  cloudwatch_role_arn = "${aws_iam_role.api_gw_role.arn}"
}
