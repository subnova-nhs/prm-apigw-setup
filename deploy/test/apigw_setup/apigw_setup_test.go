package apigw_test

import (
	"io/ioutil"
	"path/filepath"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws/session"

	"github.com/aws/aws-sdk-go/service/sts"
	httphelper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func generateEnvironmentName() string {
	return "test-" + random.UniqueId()
}

func getAccountID(t *testing.T) string {
	session, err := session.NewSession()
	if err != nil {
		t.Fatalf("unable to create aws session: %v", err)
	}
	svc := sts.New(session)
	out, err := svc.GetCallerIdentity(&sts.GetCallerIdentityInput{})
	if err != nil {
		t.Fatalf("unable to get caller identity: %v", err)
	}
	return *out.Account
}

func loadFile(t *testing.T, name string) []byte {
	path := filepath.Join("testdata", name) // relative path
	bytes, err := ioutil.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return bytes
}

func TestApiGatewaySetup(t *testing.T) {
	accountID := getAccountID(t)
	environmentName := generateEnvironmentName()

	// deploy the lambda
	setupOptions := &terraform.Options{
		TerraformDir: "../../src/apigw_setup",

		Vars: map[string]interface{}{
			"environment": environmentName,
			"aws_region":  "eu-west-2",
		},

		BackendConfig: map[string]interface{}{
			"bucket": "prm-" + accountID + "-test-state",
			"key":    environmentName + ".tfstate",
			"region": "eu-west-2",
		},

		NoColor: true,
	}

	defer terraform.Destroy(t, setupOptions)
	terraform.InitAndApply(t, setupOptions)

	// setup the rest of the test fixture
	postSetupOptions := &terraform.Options{
		TerraformDir: "post_setup",

		Vars: map[string]interface{}{
			"environment": environmentName,
			"aws_region":  "eu-west-2",
		},

		NoColor: true,
	}

	defer terraform.Destroy(t, postSetupOptions)
	terraform.InitAndApply(t, postSetupOptions)

	// post data at the published endpoint and verify that the response is 200
	url := terraform.Output(t, postSetupOptions, "invoke_endpoint") + "/test"

	httphelper.HttpGetWithRetry(t, url, 200, "", 3, 1*time.Second)
}
