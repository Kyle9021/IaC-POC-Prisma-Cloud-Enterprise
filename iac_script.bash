#!/bin/bash
# Written By Kyle Butler
# Tested on 6.04.2021 on prisma_cloud_enterprise_edition using Ubuntu 20.04

# Requires jq to be installed sudo apt-get install jq
# Requires cowsay: sudo apt install cowsay


# Access key should be created in the Prisma Cloud Console under: Settings > Accesskeys
# Decision to leave access keys in the script to simplify the workflow
# Recommendations for hardening are: store variables in a secret manager of choice or export the access_keys/secret_key as env variables in a separate script. 
# Place the access key and secret key between "<ACCESS_KEY>", <SECRET_KEY> marks respectively below.


# Only variable(s) needing to be assigned by and end-user
# Found on https://prisma.pan.dev/api/cloud/api-url

pcee_console_api_url="<https://API.URL>"

# Create access keys in the Prisma Cloud Enterprise Edition Console

pcee_accesskey="<ACCESS_KEY>"
pcee_secretkey="<SECRET_KEY>"

# The location of the TF or CFT template to be scanned
pcee_iac_scan_file="${HOME}/terragoat/terraform/aws/ec2.tf"

# choose either tf=terraform, cft=cloud_formation_template, k8=kubernetes_manifest
pcee_template_type="tf"

# choose either 11 = 0.11, 12 = 0.12, or 13 = 0.13
pcee_template_version="12"

# chnage the values inbetween the "<>" TODO: I'll think of a better way to do this. 
# failure criteria is specifying how many policies will "fail" a check based on the severity

pcee_iac_payload_single="
{
  'data': {
    'type': 'async-scan',
    'attributes': {
      'assetName': '<WHATEVER_YOU_WANT_THE_ASSET_TO_APPEAR_AS>',
      'assetType': '<CHOOSE_EITHER: AzureDevOps AWSCodePipeline BitbucketCloud BitbucketServer CircleCI GitHub GitLab-CICD GitLab-SCM IaC-API IntelliJ Jenkins twistcli or VSCode>',
      'tags': {
        'env': '<BOTH_KEY_AND_VALUE_CUSTOM>',
        'dept': '<BOTH_KEY_AND_VALUE_CUSTOM>',
        'dev': '<BOTH_KEY_AND_VALUE_CUSTOM>'
      },
      'scanAttributes': {
        'scantype':'vulnerability',
        'dev':'<BOTH_KEY_AND_VALUE_CUSTOM>'
      },
      'failureCriteria': {
        'high': 1,
        'medium': 1,
        'low': 1,
        'operator': 'or'
      }
    }
  }
}"

# nothing below this line needs to be configured
# formats above json correctly for api call
pcee_iac_payload="${pcee_iac_payload_single//\'/\"}"

pcee_auth_body_single="
{
 'username':'${pcee_accesskey}', 
 'password':'${pcee_secretkey}'
}"

pcee_auth_body="${pcee_auth_body_single//\'/\"}"

if ! type "jq" > /dev/null; then
  error_and_exit "jq not installed or not in execution path, jq is required for script execution."
fi

if ! type "cowsay" > /dev/null; then
  error_and_exit "cowsay not installed or not in execution path, cowsay is required for script execution."
fi
# Saves the auth token needed to access the CSPM side of the Prisma Cloud API to a variable named $pcee_auth_token

pcee_auth_token=$(curl --request POST \
                       --url "${pcee_console_api_url}/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${pcee_auth_body}" | jq -r '.token')


# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 

echo "I'm getting the tokens boss" | cowsay

# This saves the json as a variable so it can be manipulated for downstream processing below.

pcee_scan=$(curl --request POST \
                 -H "x-redlock-auth: ${pcee_auth_token}" \
                 -H 'content-type: application/vnd.api+json' \
                 -d "${pcee_iac_payload}" \
                 --url "${pcee_console_api_url}/iac/v2/scans")

# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "I'm checking the config file boss" | cowsay -t

# You need this as the scan ID it's part of the json that gets returned from the original curl request
pcee_scan_id=$(echo ${pcee_scan} | jq -r '.[].id')

# You need this part to pull out the unique URL that gets sent back to you.
pcee_scan_url=$(echo ${pcee_scan} | jq -r '.[].links.url')

# This is where you upload the files to be scanned to Prisma Cloud Enterprise Edition

curl -X PUT "${pcee_scan_url}" -T "${pcee_iac_scan_file}"


# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "Okay, I'll stage the files for scanning...whew...lot of work here" | cowsay -t

# Same thing as above, I did this to help with formatting errors while working with json in bash
pcee_temp_json_single="
{
  'data':{
    'id':'${pcee_scan_id}', 
    'attributes':{
      'templateType':'${pcee_template_type}', 
      'templateVersion':'${pcee_template_version}'
    }
  }
}"
pcee_temp_json=${pcee_temp_json_single//\'/\"}

# Starts the scan
curl --request POST \
     --header 'content-type: application/vnd.api+json' \
     --header "x-redlock-auth: ${pcee_auth_token}" \
     --url "${pcee_console_api_url}/iac/v2/scans/${pcee_scan_id}" \
     --data-raw "${pcee_temp_json}"

# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "I wonder how we did" | cowthink


# This part retrieves the scan progress. It should be converted to a "while loop" outside of a demo env. 

pcee_scan_status=$(curl -X GET "${pcee_console_api_url}/iac/v2/scans/${pcee_scan_id}/status" \
                        --header "x-redlock-auth: ${pcee_auth_token}" \
                        --header 'Content-Type: application/vnd.api+json' | jq -r '.[].attributes.status')

# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "${pcee_scan_status}" | cowthink

# In a real CI/CD workflow you'd most likely want a "while loop here" based on the response....however it's not needed to set-up a demo environment. 
sleep 10

# Retrieves the results

curl --request GET \
     --url "${pcee_console_api_url}/iac/v2/scans/${pcee_scan_id}/results" \
     --header "content-type: application/json" \
     --header "x-redlock-auth: ${pcee_auth_token}" | jq '.[]' | cowsay -f skeleton
