#!/bin/bash

# retrieves running workflow information

action=$1
jobid=$2

function status() {
    aws batch describe-jobs --jobs $jobid | jq -r .jobs[].status
}

function logs() {
    logstream=`aws batch describe-jobs --jobs $jobid | jq -r .jobs[].container.logStreamName`
    
    aws logs get-log-events --log-group-name "/aws/batch/job" --log-stream-name $logstream
}

$1