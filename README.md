# Nextflow on AWS

  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Labs](#labs)
    - [Lab 0 - Cloud9 Environment Setup](#lab-0---cloud9-environment-setup)
    - [Lab 1 - Getting started with Nextflow](#lab-1---getting-started-with-nextflow)

## Overview

The amount of genomic sequence data has exponentially increased year over year since the introduction of NextGen Sequencing nearly a decade ago.  While traditionally this data was processed using on-premise computing clusters, the scale of recent datasets, and the processing throughput needed for clinical sequencing applications can easily exceed the capabilities and availability of such hardware.  In contrast, the cloud offers unlimited computing resources that can be leveraged for highly efficient, performant, and cost effective genomics analysis workloads.

Nextflow is a highly scalable reactive open source workflow framework that runs on infrastructure ranging from personal laptops, on-premise HPC clusters, and in the cloud using services like AWS Batch - a fully managed batch processing service from Amazon Web Services.

This tutorial will walk you through how to setup AWS infrastructure and Nextflow to run genomics analysis pipelines in the cloud.  You will learn how to create AWS Batch Compute Environments and Job Queues that leverage Amazon EC2 Spot and On-Demand instances.  Using these resources, you will build architecture that runs Nextflow entirely on AWS Batch in a cost effective and scalable fashion.  You will also learn how to process large genomic datasets from Public and Private S3 Buckets. By the end of the session, you will have the resources you need to build a genomics workflow environment with Nextflow on AWS, both from scratch and using automated mechanisms like CloudFormation.

## Prerequisites

This tutorial assumes a 300 level of experience.

Attendee are expected to:

* have administrative access to an AWS Account
* be comfortable using the Linux command line (e.g. using the `bash` shell)
* be comfortable with Git version control at the command line
* have familiarity with the AWS CLI
* have familiarity with Docker based software containers
* have familiarity with genomics data formats such as FASTQ, BAM, and VCF
* have familiarity with genomics secondary analysis steps and tooling
* have familiarity with Nextflow and its domain specific workflow language

## Labs

### Lab 0 - Cloud9 Environment Setup

Start you Cloud9 IDE:

* Go to the AWS Cloud9 Console
* Go to **Your Environments**
* Select the **"genomics-workflows"** environment
* Click on the **Open IDE** button

This will launch AWS Cloud9 in a new tab of your web browser.  The IDE takes about 1-2min to spin up.

Associate an administrative role to the EC2 Instance used by Cloud9:

* Go to the AWS EC2 Console
* Select the instance named **"aws-cloud9-genomics-workflows-xxxxxx"** where "xxxxxx" is the unique id for your Cloud9 environment.
* In the **Actions** drop-down, select **Instance Settings > Attach/Replace IAM Role**
* Select the role named **"NextflowAdminInstanceRole"**
* Click **Apply**

Cloud9 normally manages IAM credentials dynamically. This isn’t currently compatible with the `nextflow` CLI, so we will disable it and rely on the IAM instance role instead.

* Goto to your Cloud9 IDE and in the Menu go to **AWS Cloud9 > Preferences**.  This will launch a new "Preferences" tab.
* Select **AWS SETTINGS**
* Turn off **AWS managed teporary credentials**
* Close the "Preference" tab
* In a bash terminal tab type the following to remove any existing credentials:

```bash
rm -vf ~/.aws/credentials
```

* Verify that credentials are based on the instance role:

```bash
aws sts get-caller-identity

# Output should look like this:
# {
#     "Account": "123456789012", 
#     "UserId": "AROA1SAMPLEAWSIAMROLE:i-01234567890abcdef", 
#     "Arn": "arn:aws:sts::123456789012:assumed-role/NextflowAdminInstanceRole/i-01234567890abcdef"
# }
```

If your output does not match the above **DO NOT PROCEED**.  Ask for assistance.

Configure the AWS CLI with the current region as default:

```bash
sudo yum install -y jq
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

echo "export ACCOUNT_ID=${ACCOUNT_ID}" >> ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region
```

Install Nextflow:

```bash
# nextflow requires java 8
sudo yum install -y java-1.8.0-openjdk

# The Cloud9 AMI is Amazon Linux 1, which defaults to Java 7
# change the default to Java 8 and set JAVA_HOME accordingly
sudo alternatives --set java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java
export JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk.x86_64

# do this so that any new shells spawned use the correct
# java version
echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bash_profile

# get and install nextflow
mkdir -p ~/bin
cd ~/bin
curl -s https://get.nextflow.io | bash

cd ~/environment
```

When the above is complete you should see something like the following:

```text
      N E X T F L O W
      version 19.07.0 build 5106
      created 27-07-2019 13:22 UTC 
      cite doi:10.1038/nbt.3820
      http://nextflow.io


Nextflow installation completed. Please note:
- the executable file `nextflow` has been created in the folder: /home/ec2-user/bin
```

### Lab 1 - Getting started with Nextflow

There are a couple key ways to run Nextflow:

*  locally for both the master process and jobs
*  locally for the master process with AWS Batch for jobs
*  (Advanced) Containerized with "Batch-Squared" Infrastructure - An AWS Batch job for the master process that creates additional AWS Batch jobs

#### Local master and jobs

You can run Nextflow workflows entire on a single compute instance.  This can either be your local laptop, or a remote server like an EC2 instance.  in this workshop, your AWS Cloud9 Environment can simulate this scenario.

In a bash terminal, type the following:

```bash
nextflow run hello
```

This will run Nextflow's built-in "hello world" workflow.

#### Local master and AWS Batch jobs

Genomics and life sciences workflows typically use a variety of tools that each have distinct computing resource requirements, such as high CPU or RAM utilization, or GPU acceleration.
Sometimes these requirements are beyond what a laptop or a single EC2 instance can provide.  Plus, provisioning a single large instance so that a couple of steps in a workflow can run would be a waste of computing resources.

A more cost effective method is to provision compute resources dynamically, as they are needed for each step of the workflow.
This is what AWS Batch is good at doing.

AWS Batch and S3 resources were created ahead of time in the event accounts used for this workshop.  If you are running this lab in your own account, use the CloudFormation templates available at the link below to setup your own environment.

[Genomics Workflows on AWS - Nextflow Full Stack](https://docs.opendata.aws/genomics-workflows/orchestration/nextflow/nextflow-overview/#full-stack-deployment)

To configure your local Nextflow installation to use AWS Batch for workflow steps (aka jobs, or processes):

* Determine the "default" queue that was created
* Determine the S3 Bucket that was created, this will be your nextflow working directory
* Create a config file

Nextflow config file:

```groovy
workDir = "s3://${WORK_BUCKET}"
process.executor = "awsbatch"
process.queue = "${DEFAULT_JOB_QUEUE}"
aws.batch.cliPath = "/home/ec2-user/miniconda/bin/aws"

```

#### Batch-Squared

Since the master `nextflow` process needs to be connected to jobs to monitor progress, using a local laptop, or a dedicated EC2 instance for the master `nextflow` process is not ideal for long running workflows.
