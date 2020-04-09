#!/bin/bash

# assume that the default region is set as a global environment variable
# alternatively get it using `aws configure get default.region`
if [ -z "$AWS_REGION" ]; then
    AWS_REGION=`aws configure get default.region`
fi

echo "pre-warming compute environments in $AWS_REGION"

function get_ce_name() {
    local ce_type=${1:-spot}  # spot | ondemand
    local ce_name=$(\
        aws --region $AWS_REGION \
            batch describe-compute-environments \
            --query "computeEnvironments[?starts_with(computeEnvironmentName, \`$ce_type\`)==\`true\`].computeEnvironmentName" \
            --output text \
    )

    echo $ce_name
}

for ce_type in spot ondemand; do
    ce_name=$(get_ce_name $ce_type)

    if [ ! -z "$ce_name" ]; then
        aws --region $AWS_REGION \
            batch update-compute-environment \
            --compute-environment $ce_name \
            --compute-resources minvCpus=8,desiredvCpus=8
    else
        echo "$ce_type compute environment not found"
    fi
done
