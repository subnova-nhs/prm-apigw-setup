data "aws_api_gateway_rest_api" "api_gw_endpoint" {
  name = "ehr-translate-${var.environment}"
}

# Deploy a mock endpoint

resource "aws_api_gateway_resource" "test_resource" {
  rest_api_id = "${data.aws_api_gateway_rest_api.api_gw_endpoint.id}"
  parent_id   = "${data.aws_api_gateway_rest_api.api_gw_endpoint.root_resource_id}"
  path_part   = "test"
}

resource "aws_api_gateway_method" "test_get_method" {
  rest_api_id   = "${data.aws_api_gateway_rest_api.api_gw_endpoint.id}"
  resource_id   = "${aws_api_gateway_resource.test_resource.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "api_gw_integration" {
  rest_api_id = "${data.aws_api_gateway_rest_api.api_gw_endpoint.id}"
  resource_id = "${aws_api_gateway_resource.test_resource.id}"
  http_method = "${aws_api_gateway_method.test_get_method.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_integration" "api_gw_integration" {
  rest_api_id = "${data.aws_api_gateway_rest_api.api_gw_endpoint.id}"
  resource_id = "${aws_api_gateway_resource.test_resource.id}"
  http_method = "${aws_api_gateway_method.test_get_method.http_method}"
  type        = "MOCK"

  request_templates = {
    "application/json"  = <<EOF
{"statusCode":200}
EOF
  }
}

resource "aws_api_gateway_integration_response" "api_gw_integration" {
  rest_api_id = "${data.aws_api_gateway_rest_api.api_gw_endpoint.id}"
  resource_id = "${aws_api_gateway_resource.test_resource.id}"
  http_method = "${aws_api_gateway_method.test_get_method.http_method}"
  status_code = "${aws_api_gateway_method_response.api_gw_integration.status_code}"
}

# Deploy the endpoint

module "apigw_deploy" {
  source = "github.com/subnova-nhs/prm-apigw-deploy/deploy/src//modules/apigw_deploy"

  aws_region = "${var.aws_region}"
  environment = "${var.environment}"

  depends_on = [
    "${aws_api_gateway_integration.api_gw_integration.id}",
    "${aws_api_gateway_integration_response.api_gw_integration.id}", 
    "${aws_api_gateway_method_response.api_gw_integration.id}"
  ]

  depends_on_count = 3
}
