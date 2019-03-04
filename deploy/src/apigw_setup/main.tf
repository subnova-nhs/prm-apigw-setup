module "apigw_setup" {
  source = "../modules/apigw_setup"

  aws_region = "${var.aws_region}"
  environment = "${var.environment}"
}
