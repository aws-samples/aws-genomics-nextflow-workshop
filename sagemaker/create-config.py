#!/usr/bin/env python

import boto3

batch = boto3.client('batch')

jobdefs = batch.describe_job_definitions(jobDefinitionName="nextflow")['jobDefinitions']
latest = max([jobdef['revision'] for jobdef in jobdefs])

jobdef = list(filter(lambda j: j['revision'] == latest, jobdefs))[0]
env_vars = jobdef['containerProperties']['environment']

# retrieve export values that are needed for configuring nextflow
env = {
    "nf_workdir": None,
    "nf_job_queue": None,
}

def get_value(env_vars, name):
    for var in env_vars:
        if var['name'].lower() == name.lower():
            return {name: var['value']}

env.update(get_value(env_vars, 'nf_workdir'))
env.update(get_value(env_vars, 'nf_job_queue'))

config_tpl = """
workDir = "{nf_workdir}"
process.executor = "awsbatch"
process.queue = "{nf_job_queue}"
aws.batch.cliPath = "/home/ec2-user/miniconda/bin/aws"
"""

print(config_tpl.format(**env).strip())
