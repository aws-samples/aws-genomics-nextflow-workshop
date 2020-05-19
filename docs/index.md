# Nextflow on AWS

![Nextflow on AWS](./images/nextflow-on-aws-infrastructure.png)

## Overview

The amount of genomic sequence data has exponentially increased year over year since the introduction of NextGen Sequencing nearly a decade ago.  While traditionally this data was processed using on-premise computing clusters, the scale of recent datasets, and the processing throughput needed for clinical sequencing applications can easily exceed the capabilities and availability of such hardware.  In contrast, the cloud offers unlimited computing resources that can be leveraged for highly efficient, performant, and cost effective genomics analysis workloads.

Nextflow is a highly scalable reactive open source workflow framework that runs on infrastructure ranging from personal laptops, on-premise HPC clusters, and in the cloud using services like AWS Batch - a fully managed batch processing service from Amazon Web Services.

This tutorial will walk you through how to setup AWS infrastructure and Nextflow to run genomics analysis pipelines in the cloud.  You will learn how to create AWS Batch Compute Environments and Job Queues that leverage Amazon EC2 Spot and On-Demand instances.  Using these resources, you will build architecture that runs Nextflow entirely on AWS Batch in a cost effective and scalable fashion.  You will also learn how to process large genomic datasets from Public and Private S3 Buckets. By the end of the session, you will have the resources you need to build a genomics workflow environment with Nextflow on AWS, both from scratch and using automated mechanisms like CloudFormation.

## Prerequisites

Attendees are expected to:

* have administrative access to an AWS Account
* be comfortable using the Linux command line (e.g. using the `bash` shell)
* be comfortable with Git version control at the command line
* have familiarity with the AWS CLI
* have familiarity with Docker based software containers
* have familiarity with genomics data formats such as FASTQ, BAM, and VCF
* have familiarity with genomics secondary analysis steps and tooling
* have familiarity with Nextflow and its domain specific workflow language

If you are attending this workshop in person, all AWS resources will be created for you in an event account.  Otherwise you can create resources in your account and run through the workshop at your own pace with the following:

* [AWS Cloud9 Environment](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Nextflow&templateURL=https://s3.amazonaws.com/pwyming-demo-templates/nextflow-workshop/cloud9.cfn.yaml)
* [Nextflow on AWS Batch](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=Nextflow&templateURL=https://s3.amazonaws.com/pwyming-demo-templates/nextflow-workshop/nextflow/nextflow-aio.template.yaml)

The above links will launch AWS Cloudformation Stacks to build the resources needed for the workshop.
<<<<<<< HEAD
=======

## Downloads

* [Workshop Slides 2020](./downloads/nextflow-workshop_2020.pdf)
>>>>>>> master
