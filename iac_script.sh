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
# Example of a better way: pcee_console_api_url=$(vault kv get -format=json <secret/path> | jq -r '.<resources>')
pcee_accesskey="<ACCESS_KEY>"
pcee_secretkey="<SECRET_KEY>"

# The location of the TF or CFT template to be scanned
pcee_iac_scan_file="${HOME}/terragoat/terraform/aws/ec2.tf"

# Choose either tf=terraform, cft=cloud_formation_template, k8=kubernetes_manifest
pcee_template_type="tf"

# Choose either 11 = 0.11, 12 = 0.12, or 13 = 0.13
pcee_template_version="12"

# Change the values inbetween the "<>" TODO: I'll think of a better way to do this. 
# Failure criteria is specifying how many policies will "fail" a check based on the severity

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

# debugging to ensure jq and cowsay are installed

if ! type "jq" > /dev/null; then
  error_and_exit "jq not installed or not in execution path, jq is required for script execution."
fi

if ! type "cowsay" > /dev/null; then
  error_and_exit "cowsay not installed or not in execution path, cowsay is required for script execution."
fi

# debugging to ensure the variables are assigned correctly not required

if [ ! -n "$pcee_console_api_url" ] || [ ! -n "$pcee_secretkey" ] || [ ! -n "$pcee_accesskey" ]; then
  echo "pcee_console_api_url or pcee_accesskey or pcee_secret key came up null" | cowsay;
  exit;
fi

if [[ ! $pcee_console_api_url =~ ^(\"\')?https\:\/\/api[2-3]?\.prismacloud\.io(\"|\')?$ ]]; then
  echo "pcee_console_api_url variable isn't formatted or assigned correctly" | cowsay;
  exit;
fi

if [[ ! $pcee_accesskey =~ ^.{35,40}$ ]]; then
  echo "check the pcee_accesskey variable because it doesn't appear to be the correct length" | cowsay;
  exit;
fi

if [[ ! $pcee_secretkey =~ ^.{27,31}$ ]]; then
  echo "check the pcee_accesskey variable because it doesn't appear to be the correct length" | cowsay;
  exit;
fi

if [[ ! -f $pcee_iac_scan_file ]]; then
  echo "check to see if the pcee_iac_scan_file variable is assigned correctly; because, file not found" | cowsay;
  exit;
fi



# Saves the auth token needed to access the CSPM side of the Prisma Cloud API to a variable named $pcee_auth_token

pcee_auth_token=$(curl -s --request POST \
                       --url "${pcee_console_api_url}/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${pcee_auth_body}" | jq -r '.token')


if [[ $(printf %s "${pcee_auth_token}") == null ]]; then
  echo "I couldn't get the jwt boss, check your access key and secret key variables and the expiration date" | cowsay;
  exit;
else
  echo "I recieved the jwt/red-lock auth token boss!" | cowsay;
fi

# This saves the json as a variable so it can be manipulated for downstream processing below.

pcee_scan=$(curl -s --request POST \
                 -H "x-redlock-auth: ${pcee_auth_token}" \
                 -H 'content-type: application/vnd.api+json' \
                 -d "${pcee_iac_payload}" \
                 --url "${pcee_console_api_url}/iac/v2/scans")
                 
pcee_scan_check=$?
if [ $pcee_scan_check != 0 ]; then
  echo "check the pcee_iac_payload_single variable" | cowsay;
  exit;
fi

# You need this as the scan ID it's part of the json that gets returned from the original curl request
pcee_scan_id=$(echo ${pcee_scan} | jq -r '.[].id')

pcee_scan_id_check=$?
if [ $pcee_scan_id_check != 0 ]; then
  echo "the repsonse isn't valid, there's an issue with the api endpoint" | cowsay;
  echo "$pcee_scan" | jq -r '. | {error_code: .errors[].status, details: .errors[].detail}' | cowsay;
  exit;
fi

# You need this part to pull out the unique URL that gets sent back to you.
pcee_scan_url=$(echo ${pcee_scan} | jq -r '.[].links.url')

if [ $pcee_scan_url_check != 0 ]; then
  echo "repsonse not valid, something might be up with the api endpoint" | cowsay;
  echo "$pcee_scan" | jq -r '. | {error_code: .errors[].status, details: .errors[].detail}' | cowsay;
  exit;
fi


# This is where you upload the files to be scanned to Prisma Cloud Enterprise Edition

curl -X PUT "${pcee_scan_url}" -T "${pcee_iac_scan_file}"pcee_upload_check=$?

if [ $pcee_upload_check != 0 ]; then
  echo "upload of file failed, nothing on your end" | cowsay;
  exit;
fi

echo "File(s) uploaded successfully" | cowsay -t

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
curl -s --request POST \
     --header 'content-type: application/vnd.api+json' \
     --header "x-redlock-auth: ${pcee_auth_token}" \
     --url "${pcee_console_api_url}/iac/v2/scans/${pcee_scan_id}" \
     --data-raw "${pcee_temp_json}"

pcee_scan_start_check=$?
if [ $pcee_scan_start_check != 0 ]; then
  echo "failed to start the scan; most likely an internal issue" | cowsay;
  exit;
fi


# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "Scan started" | cowthink


# This part retrieves the scan progress. It should be converted to a "while loop" outside of a demo env. 

pcee_scan_status=$(curl -s --request GET "${pcee_console_api_url}/iac/v2/scans/${pcee_scan_id}/status" \
                        --header "x-redlock-auth: ${pcee_auth_token}" \
                        --header 'Content-Type: application/vnd.api+json' | jq -r '.[].attributes.status')


pcee_scan_status_check=$?
if [ $pcee_scan_status_check != 0 ]; then
  echo "something failed during processing. Not an issue on your end" | cowsay;
  exit;
fi

# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "${pcee_scan_status}" | cowthink

# In a real CI/CD workflow you'd most likely want a "while loop here" based on the response....however it's not needed to set-up a demo environment. 
sleep 10

# Retrieves the results

pcee_iac_results=$(curl -s --request GET \
                        --url "${pcee_console_api_url}/iac/v2/scans/${pcee_scan_id}/results" \
                        --header "content-type: application/json" \
                        --header "x-redlock-auth: ${pcee_auth_token}")


pcee_iac_results_check=$?
if [ $pcee_iac_results_check != 0 ]; then
  echo "If you're uploading more than one file at a time, change the sleep command on line 230." | cowsay;
  exit;
fi

echo "${pcee_iac_results}" | jq '.data[] | {issue: .attributes.name, severity: .attributes.severity, rule: .attributes.rule, description: .attributes.desc, pan_link: .attributes.docUrl, file: .attributes.blameList[].file, path: .attributes.blameList[].locations[].path, line: .attributes.blameList[].locations[].line}'| cowsay -W 80

echo "details above" | cowsay

echo "On today's date: $(date)"
echo "$(echo ${pcee_iac_results} | jq '.meta.matchedPoliciesSummary.high') high severity issue(s) found"
echo "$(echo ${pcee_iac_results} | jq '.meta.matchedPoliciesSummary.medium') medium severity issue(s) found"
echo "$(echo ${pcee_iac_results} | jq '.meta.matchedPoliciesSummary.low') low severity issue(s) found"
