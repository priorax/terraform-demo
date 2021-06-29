package test

import (
	"crypto/tls"
	"fmt"
	"testing"
	"time"
	"strings"
	"github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// An example of how to test the Terraform module in examples/terraform-http-example using Terratest.
func TestTerraformHttpExample(t *testing.T) {
	t.Parallel()

	awsRegion := "ap-southeast-2"
	uniqueId := random.UniqueId()

	// Create an S3 bucket where we can store state
	bucketName := fmt.Sprintf("test-terraform-backend-example-%s", strings.ToLower(uniqueId))
	defer cleanupS3Bucket(t, awsRegion, bucketName)
	aws.CreateS3Bucket(t, awsRegion, bucketName)

	key := fmt.Sprintf("%s/terraform.tfstate", uniqueId)

	// Construct the terraform options with default retryable errors to handle the most common retryable errors in
	// terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "..",

		// Variables to pass to our Terraform code using -var options
		
		BackendConfig: map[string]interface{}{
			"bucket": bucketName,
			"key":    key,
			"region": awsRegion,
		},
		Reconfigure: true,
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the value of an output variable
	instanceURL := terraform.Output(t, terraformOptions, "hostname")

	// Setup a TLS configuration to submit with the helper, a blank struct is acceptable
	tlsConfig := tls.Config{}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 15
	timeBetweenRetries := 15 * time.Second
	url := fmt.Sprintf("http://%s", instanceURL)
	http_helper.HttpGetWithRetryWithCustomValidationE(t, url, &tlsConfig, maxRetries, timeBetweenRetries, validateRequest)
}

func validateRequest(x int, _ string) bool {
	if (x < 400) {
		return true
	}
	return false
}

func cleanupS3Bucket(t *testing.T, awsRegion string, bucketName string) {
	aws.EmptyS3Bucket(t, awsRegion, bucketName)
	aws.DeleteS3Bucket(t, awsRegion, bucketName)
}