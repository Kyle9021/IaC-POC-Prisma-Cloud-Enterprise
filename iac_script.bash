#!/bin/bash
# Written By Kyle Butler
# Tested on 5.4.2021 on prisma_cloud_enterprise_edition using Ubuntu 20.04

# Requires jq to be installed sudo apt-get install jq
# (optional but not required) cowsay: sudo apt install cowboy


# Access key should be created in the Prisma Cloud Console under: Settings > Accesskeys
# I'm making a conscious decision to leave access keys in the script to simplify the workflow
# My recommendations for hardening is to store these variables in a secret manager of choice or
# export the access keys/secret key as env variables in a separate script. 
# Place the access key and secret key between "<ACCESS_KEY>", <SECRET_KEY> marks respectively below.


# Only variable(s) needing to be assigned by and end-user
# Found on https://prisma.pan.dev/api/cloud/api-urls, replace value below

pcee_console_api_url="api.prismacloud.io"

# Create access keys in the Prisma Cloud Enterprise Edition Console

pcee_accesskey="<ACCESS_KEY>"
pcee_secretkey="<SECRET_KEY>"

# This is where the tags, and scan information live. Recommending putting this script in the same directory as the this file so you don't need to alter the location below. 

pcee_payload_file_location="./config-file-template.json"


# TF Template to be scanned, put the file location path. No need to change if you follow the README to a T below:

pcee_iac_scan_file=""${HOME}"/terragoat/terraform/aws/ec2.tf"

# choose either tf=terraform, cft=cloud_formation_template, k8=kubernetes_manifest
pcee_template_type="tf"

# choose either 11 = 0.11, 12 = 0.12, or 13 = 0.13
pcee_template_version="12"

# This is found  in the Prisma Cloud Console under: Compute > Manage/System on the downloads tab under Path to Console
pcee_console_url="<REPLACE_WITH_THE_APPROPRIATE_VALUE_FOUND_ABOVE>"


# NOTHING BELOW THIS LINE NEEDS TO BE ALTERED

# so the json "config" file can be read by the curl command properly. 
pcee_payload_file=$(cat "${pcee_payload_file_location}")

# This variable formats everything correctly so that the next variable can be assigned.
pcee_auth_body="{\"username\":\""${pcee_accesskey}"\", \"password\":\""${pcee_secretkey}"\"}"

# This saves the auth token needed to access the CSPM side of the Prisma Cloud API to a variable I named $pcee_auth_token
pcee_auth_token=$(curl --request POST \
--url https://"${pcee_console_api_url}"/login \
--header 'Accept: application/json; charset=UTF-8' \
--header 'Content-Type: application/json; charset=UTF-8' \
--data "${pcee_auth_body}" | jq -r '.token')

# This variable formats everything correctly so that the next variable can be assigned.
pcee_compute_auth_body="{\"username\":\""${pcee_accesskey}"\", \"password\":\""${pcee_secretkey}"\"}"

# This saves the auth token needed to access the CWPP side of the Prisma Cloud API to a variable $pcee_compute_token
pcee_compute_token=$(curl \
-H "Content-Type: application/json" \
-d "${pcee_compute_auth_body}" \
"${pcee_console_url}"/api/v1/authenticate | jq -r '.token')


# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 

echo "I'm getting the tokens boss" | cowsay


# Everything here is for container scanning. Delete or disregard. 
# Download the latest twistcli tool
# curl --header "authorization: Bearer "${pcee_compute_token}"" \
# "${pcee_console_url}"/api/v1/util/twistcli > twistcli; chmod a+x twistcli;

# Scan with twistcli ----for containers

# ./twistcli image scan --token "${pcee_compute_token}"\
# --config-file "${pcee_iac_config_file_location}"\
# --type "${pcee_iac_file_type}" --files "${pcee_iac_scan_file}"\
# --compliance-threshold "${pcee_iac_compliance_threshold}"
# --address "${pcee_console_url}" --output-file "${PWD}"
# End of Container Scanning section ---


# This saves the json as a variable so it can be manipulated for downstream processing below.

pcee_scan=$(curl \
--request POST \
-H "x-redlock-auth: "${pcee_auth_token}"" \
-H 'content-type: application/vnd.api+json' \
-d "${pcee_payload_file}" \
--url "https://"${pcee_console_api_url}"/iac/v2/scans")

# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "I'm checking the config file boss" | cowsay -t

# You need this as the scan ID it's part of the json that gets returned from the original curl request
pcee_scan_id=$(echo ${pcee_scan} | jq -r '.[] | {scan_id: .id}' | jq -r '.scan_id')

# You need this part to pull out the unique URL that gets sent back to you.
pcee_scan_url=$(echo ${pcee_scan} | jq '.[] | {scan_url: .links.url}' | jq -r '.scan_url')

# This is where you upload the files to be scanned to Prisma Cloud Enterprise Edition

curl -s -X PUT "${pcee_scan_url}" -T "${pcee_iac_scan_file}"


# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "Okay, I'll stage the files for scanning...whew...lot of work here" | cowsay -t

# Same thing as above, I did this to help with formatting errors while working with json in bash
pcee_temp_json="{\"data\":{\"id\":\""${pcee_scan_id}"\", \"attributes\":{\"templateType\":\""${pcee_template_type}"\", \"templateVersion\":\""${pcee_template_version}"\"}}}"

# Starts the scan
curl --request POST \
--header 'content-type: application/vnd.api+json' \
--header "x-redlock-auth: "${pcee_auth_token}"" \
--url "https://"${pcee_console_api_url}"/iac/v2/scans/"${pcee_scan_id}"" \
--data-raw "${pcee_temp_json}"

# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "I wonder how we did" | cowthink


# This part retrieves the scan progress. It should be converted to a "while loop" outside of a demo env. 

pcee_scan_status=$(curl -X GET "https://"${pcee_console_api_url}"/iac/v2/scans/"${pcee_scan_id}"/status" \
--header "x-redlock-auth: "${pcee_auth_token}"" \
--header 'Content-Type: application/vnd.api+json' | jq '.[] | {status: .attributes.status}' \
|jq -r .status)

# Put a '#' in front of the line directly below this to disable cowsay. Cowsay is required to be installed if you want to run this. 
echo "${pcee_scan_status}" | cowthink

sleep 5

# Retrieves the results
 
curl --request GET \
--url "https://"${pcee_console_api_url}"/iac/v2/scans/"${pcee_scan_id}"/results" \
--header "content-type: application/json" \
--header "x-redlock-auth: "${pcee_auth_token}"" | jq '.[]' | cowsay -f skeleton 
