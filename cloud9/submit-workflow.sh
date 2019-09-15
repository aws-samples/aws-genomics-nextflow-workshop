#!/bin/bash

# Helper script for submitting nextflow workflows to Batch-squared architecture
# Workflows are submitted to the first "highpriority" Batch Job Queue found in
# in the default AWS region configured for the user.
#
# Usage:
# submit-workflow.sh WORKFLOW_NAME (file://OVERRIDES_JSON | (CONTAINER_ARGS ...))
#
# Examples:
# submit-workflow.sh hello file://hello.overrides.json
# submit-workflow.sh hello hello

WORKFLOW_NAME=$1  # custom name for workflow
shift
PARAMS=("$@")     # args or path to json file for job overrides, e.g. file://path/to/overrides.json

# assume that the default region is set as a global environment variable
# alternatively get it using `aws configure get default.region`
if [ -z "$AWS_REGION" ]; then
    AWS_REGION=`aws configure get default.region`
fi

if [[ ${PARAMS[0]} == file://* ]]; then
    # user provided a file path to an overrides json
    # shift remaining args
    OVERRIDES=${PARAMS[0]}
    shift
else
    # construct a comma separated list for shorthand overrides notation
    OVERRIDES=$(printf "'%s'," ${PARAMS[@]})
    OVERRIDES="command=${OVERRIDES%,}"
fi

# get the name of the high-priority queue
HIGHPRIORITY_JOB_QUEUE=$(aws --region $AWS_REGION batch describe-job-queues | jq -r .jobQueues[].jobQueueName | grep highpriority)

if [ -z "$HIGHPRIORITY_JOB_QUEUE" ]; then
    echo "no highpriority job queue found"
    exit 1
fi

# submits nextflow workflow to AWS Batch
# command is printed to stdout for debugging
COMMAND=$(cat <<EOF
aws batch submit-job \
    --region $AWS_REGION \
    --job-definition nextflow \
    --job-name nf-workflow-${WORKFLOW_NAME} \
    --job-queue ${HIGHPRIORITY_JOB_QUEUE} \
    --container-overrides ${OVERRIDES}
EOF
)

echo $COMMAND
${COMMAND}