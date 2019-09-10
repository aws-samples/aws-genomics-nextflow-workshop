#!/bin/bash

# Usage: batch-test.sh [high|low] for high priority or spot queue

# retrieve the current region using instance metadata
sudo yum install -y jq
REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

# REGION=us-east-1
# # Frankfurt
# REGION=eu-central-1
# #Dublin
# REGION=eu-west-1

WORKFLOW=hello
hiQUEUE=`aws batch describe-job-queues --region $REGION | grep jobQueueName | awk -F: '{ print $2}' | grep high | sed s/\"//g`
lowQUEUE=`aws batch describe-job-queues --region $REGION | grep jobQueueName | awk -F: '{ print $2}' | grep default | sed s/\"//g`

if [ $1 = "high" ]
then
	QUEUE=$hiQUEUE
else
	QUEUE=$lowQUEUE
fi

echo $QUEUE

OVERRIDES=$(cat <<EOF
{"command": ["''", "hello"]}
EOF
)

aws batch submit-job \
    --region ${REGION} \
    --job-name nf-workflow-${WORKFLOW} \
    --job-queue ${QUEUE} \
    --job-definition nextflow \
    --container-overrides "${OVERRIDES}"
