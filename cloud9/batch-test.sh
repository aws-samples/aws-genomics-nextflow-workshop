#!/bin/bash

# Usage: batch-test.sh [high|low] for high priority or spot queue
REGION=us-east-1
WORKFLOW=hello
hiQUEUE=`aws batch describe-job-queues --region us-east-1 | grep jobQueueName | awk -F: '{ print $2}' | grep high | sed s/\"//g`
lowQUEUE=`aws batch describe-job-queues --region us-east-1 | grep jobQueueName | awk -F: '{ print $2}' | grep default | sed s/\"//g`
#QUEUE=highpriority-40cc9c20-a208-11e9-8a19-0e7698e0f2e8
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