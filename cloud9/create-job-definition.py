#!/usr/bin/env python

import boto3
import json

cfn = boto3.client('cloudformation')

exports = cfn.list_exports()['Exports']

# retrieve export values that are needed for configuring nextflow
def get_export(exports, name):
    for export in exports:
        if '-' + name in export['Name']:
            return {name: export['Value']}

jobdef = {
    "jobDefinitionName": "nextflow",
    "type": "container",
    "containerProperties": {
        "image": get_export(exports, 'NextflowContainerImage'),
        "vcpus": 2,
        "memory": 1024,
        "jobRoleArn": get_export(exports, 'NextflowJobRoleArn'),
        "environment": [
            {
                "name": "NF_LOGSDIR",
                "value": get_export(exports, 'NextflowLogsDir')
            },
            {
                "name": "NF_JOB_QUEUE",
                "value": get_export(exports, 'DefaultJobQueue')
            },
            {
                "name": "NF_WORKDIR",
                "value": get_export(exports, 'NextflowWorkDir')
            }
        ]
    }
}

print(json.dumps(jobdef, indent=2))