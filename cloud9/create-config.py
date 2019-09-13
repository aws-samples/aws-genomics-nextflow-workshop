#!/usr/bin/env python

import boto3

cfn = boto3.client('cloudformation')

exports = cfn.list_exports()['Exports']

# retrieve export values that are needed for configuring nextflow
env = {
    "NextflowWorkDir": None,
    "DefaultJobQueue": None,
}

def get_export(exports, name):
    for export in exports:
        if '-' + name in export['Name']:
            return {name: export['Value']}

env.update(get_export(exports, 'NextflowWorkDir'))
env.update(get_export(exports, 'DefaultJobQueue'))

config_tpl = """
workDir = "{NextflowWorkDir}"
process.executor = "awsbatch"
process.queue = "{DefaultJobQueue}"
aws.batch.cliPath = "/home/ec2-user/miniconda/bin/aws"
"""

print(config_tpl.format(**env).strip())