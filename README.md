# Nextflow on AWS

- [Nextflow on AWS](#nextflow-on-aws)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Module 0 - Cloud9 Environment Setup](#module-0---cloud9-environment-setup)
  - [Module 1 - AWS Resources](#module-1---aws-resources)
    - [S3 Bucket](#s3-bucket)
    - [IAM Roles](#iam-roles)
      - [Create a Batch Service Role](#create-a-batch-service-role)
      - [Create an EC2 SpotFleet Role](#create-an-ec2-spotfleet-role)
      - [Create an IAM Policies](#create-an-iam-policies)
        - [Bucket access policy](#bucket-access-policy)
        - [EBS volume policy](#ebs-volume-policy)
      - [Create an EC2 Instance Role](#create-an-ec2-instance-role)
    - [EC2 Launch Template](#ec2-launch-template)
    - [Batch Compute Environments](#batch-compute-environments)
      - [Create an "optimal" on-demand compute environment](#create-an-%22optimal%22-on-demand-compute-environment)
      - [Create an "optimal" spot compute environment](#create-an-%22optimal%22-spot-compute-environment)
    - [Batch Job Queues](#batch-job-queues)
      - [Create a "default" job queue](#create-a-%22default%22-job-queue)
      - [Create a "high-priority" job queue](#create-a-%22high-priority%22-job-queue)
  - [Module 2 - Running Nextflow](#module-2---running-nextflow)
    - [Local master and jobs](#local-master-and-jobs)
    - [Local master and AWS Batch jobs](#local-master-and-aws-batch-jobs)
    - [Batch-Squared](#batch-squared)
      - [Containerizing Nextflow](#containerizing-nextflow)
        - [`Dockerfile`](#dockerfile)
        - [`nextflow.aws.sh`](#nextflowawssh)
      - [Batch Job Definition for Nextflow](#batch-job-definition-for-nextflow)
      - [Submitting a Nextflow workflow](#submitting-a-nextflow-workflow)
      - [Run a realistic demo workflow](#run-a-realistic-demo-workflow)
      - [Run an NF-Core wokflow](#run-an-nf-core-wokflow)
  - [Module 3 - Automation](#module-3---automation)

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

## Module 0 - Cloud9 Environment Setup

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

Install boto3 for Python 3:

```bash
sudo yum install -y python36-pip
pip-3.6 install --user boto3
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

## Module 1 - AWS Resources

This module will cover building the AWS resources you need to run Nextflow on AWS from scratch.

If you are attending an in person workshop, these resources have been created ahead of time in the AWS accounts you were provided.  During the workshop we'll walk through all the pieces of the architecture at a high level so you know how everything is wired together.

### S3 Bucket

You'll need an S3 bucket to store both your input data and workflow results.
S3 is an ideal location to store datasets of the size encountered in genomics, 
which often equal or exceed 100GB per sample file.

S3 also makes it easy to collaboratively work on such large datasets because buckets
and the data stored in them are globally available.

* Go to the S3 Console
* Click on the "Create Bucket" button

In the dialog that opens:

  * Provide a "Bucket Name".  This needs to be globally unique.  A pattern that usually works is

```text
<workshop-name>-<your-initials>-<date>
```

for example:

```text
nextflow-workshop-abc-20190101
```

  * Select the region for the bucket.  Buckets are globally accessible, but the data resides on physical hardware with in a specific region.  It is best to choose a region that is closest to where you are and where you will launch compute resources to reduce network latency and avoid inter-region transfer costs.

The default options for bucket configuration are sufficient for the purposes of this workshop.

* Click the "Create" button to accept defaults and create the bucket.


### IAM Roles

IAM is used to control access to your AWS resources.  This includes access by users and groups in your account, as well as access by AWS services operating on your behalf.

Services use IAM Roles which provide temporary access to AWS resources when needed.

> **IMPORTANT**
> 
> You need to have Administrative access to your AWS account to create IAM roles.
>
> A recommended way to do this is to create a user and add that user to a group
> with the `AdministratorAccess` managed policy attached.  This makes it easier to 
> revoke these privileges if necessary.

#### Create a Batch Service Role

This is a role used by AWS Batch to launch EC2 instances on your behalf.

* Go to the IAM Console
* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose "Batch" as the service to use the role
* Click "Next: Permissions"

In Attached permissions policies, the "AWSBatchServiceRole" will already be attached

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "AWSBatchServiceRole"
* Click "Create role"


#### Create an EC2 SpotFleet Role

This is a role that allows creation and launch of Spot fleets - Spot instances with similar compute capabilities (i.e. vCPUs and RAM).  This is for using Spot instances when running jobs in AWS Batch.

* Go to the IAM Console
* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose EC2 from the larger services list
* Choose "EC2 - Spot Fleet Tagging" as the use case

In Attached permissions policies, the "AmazonEC2SpotFleetTaggingRole" will already be attached

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "AWSSpotFleetTaggingRole"
* Click "Create role"


#### Create an IAM Policies

For the EC2 instance role in the next section, it is recommended to restrict access to just the resources and permissions it needs to use.  In this case, it will be:

* Access to the specific buckets used for input and output data
* The ability to create and add EBS volumes to the instance (more on this later)

These policies could be used by other roles, so it will be easier to manage if it each are stand alone documents.

##### Bucket access policy

* Go to the IAM Console
* Click on "Policies"
* Click on "Create Policy"
* Repeat the following for as many buckets as you will use (e.g. if you have one bucket for nextflow logs and another for nextflow workDir, you will need to do this twice)
  * Select "S3" as the service
  * Select "All Actions"
  * Under Resources select "Specific"
  * Under Resources > bucket, click "Add ARN"
    * Type in the name of the bucket
    * Click "Add"
  * Under Resources > object, click "Add ARN"
    * For "Bucket Name", type in the name of the bucket
    * For "Object Name", select "Any"
  * Click "Add additional permissions" if you have additional buckets you are using
* Click "Review Policy"
* Name the policy "bucket-access-policy"
* Click "Create Policy"

##### EBS volume policy

* Go to the IAM Console
* Click on "Policies"
* Click on "Create Policy"
* Switch to the "JSON" tab
* Paste the following into the editor:

```json
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": [
            "ec2:createVolume",
            "ec2:attachVolume",
            "ec2:deleteVolume",
            "ec2:modifyInstanceAttribute",
            "ec2:describeVolumes"
        ],
        "Resource": "*",
        "Effect": "Allow"
    }
}
```

* Click "Review Policy"
* Name the policy "ebs-autoscale-policy"
* Click "Create Policy"


#### Create an EC2 Instance Role

This is a role that controls what AWS Resources EC2 instances launched by AWS Batch have access to.
In this case, you will limit S3 access to just the bucket you created earlier.

* Go to the IAM Console
* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose EC2 from the larger services list
* Choose "EC2 - Allows EC2 instances to call AWS services on your behalf" as the use case.
* Click "Next: Permissions"

* Type "ContainerService" in the search field for policies
* Click the checkbox next to "AmazonEC2ContainerServiceforEC2Role" to attach the policy

* Type "S3" in the search field for policies
* Click the checkbox next to "AmazonS3ReadOnlyAccess" to attach the policy
  
> NOTE
>
> Enabling Read-Only access to all S3 resources is required if you use publicly available datasets such as the [1000 Genomes dataset](https://registry.opendata.aws/1000-genomes/), and others, available in the [AWS Registry of Open Datasets](https://registry.opendata.aws)

* Type "bucket-access-policy" in the search field for policies
* Click the checkbox next to "bucket-access-policy" to attach the policy

* Type "ebs-autoscale-policy" in the search field for policies
* Click the checkbox next to "ebs-autoscale-policy" to attach the policy

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "ecsInstanceRole"
* Click "Create role"


### EC2 Launch Template

An EC2 Launch Template is used to predefine EC2 instance configuration options such as Amazon Machine Image (AMI), Security Groups, and EBS volumes.  They can also be used to define User Data scripts to provision instances when they boot.  This is simpler than creating (and maintaining) a custom AMI in cases where the provisioning reequirements are simple (e.g. addition of small software utilities) but potentially changing often with new versions.

AWS Batch supports both custom AMIs and EC2 Launch Templates as methods to bootstrap EC2 instances launched for job execution.

In most cases, EC2 Launch Templates can be created using the AWS EC2 Console.
For this case, we need to use the AWS CLI.

Create a file named `launch-template-data.json` with the following contents:

```json
{
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {
          "Key": "architecture",
          "Value": "genomics-workflow"
        },
        {
          "Key": "solution",
          "Value": "nextflow"
        }
      ]
    }
  ],
  "BlockDeviceMappings": [
    {
      "Ebs": {
        "DeleteOnTermination": true,
        "VolumeSize": 50,
        "VolumeType": "gp2"
      },
      "DeviceName": "/dev/xvda"
    },
    {
      "Ebs": {
        "Encrypted": true,
        "DeleteOnTermination": true,
        "VolumeSize": 75,
        "VolumeType": "gp2"
      },
      "DeviceName": "/dev/xvdcz"
    },
    {
      "Ebs": {
        "Encrypted": true,
        "DeleteOnTermination": true,
        "VolumeSize": 20,
        "VolumeType": "gp2"
      },
      "DeviceName": "/dev/sdc"
    }
  ],
  "UserData": "TUlNRS1WZXJzaW9uOiAxLjAKQ29udGVudC1UeXBlOiBtdWx0aXBhcnQvbWl4ZWQ7IGJvdW5kYXJ5PSI9PUJPVU5EQVJZPT0iCgotLT09Qk9VTkRBUlk9PQpDb250ZW50LVR5cGU6IHRleHQvY2xvdWQtY29uZmlnOyBjaGFyc2V0PSJ1cy1hc2NpaSIKCnBhY2thZ2VzOgotIGpxCi0gYnRyZnMtcHJvZ3MKLSBweXRob24yNy1waXAKLSBzZWQKLSB3Z2V0CgpydW5jbWQ6Ci0gcGlwIGluc3RhbGwgLVUgYXdzY2xpIGJvdG8zCi0gc2NyYXRjaFBhdGg9Ii92YXIvbGliL2RvY2tlciIKLSBhcnRpZmFjdFJvb3RVcmw9Imh0dHBzOi8vczMuYW1hem9uYXdzLmNvbS9hd3MtZ2Vub21pY3Mtd29ya2Zsb3dzL2FydGlmYWN0cyIKLSBzZXJ2aWNlIGRvY2tlciBzdG9wCi0gY3AgLWF1IC92YXIvbGliL2RvY2tlciAvdmFyL2xpYi9kb2NrZXIuYmsgIAotIGNkIC9vcHQgJiYgd2dldCAkYXJ0aWZhY3RSb290VXJsL2F3cy1lYnMtYXV0b3NjYWxlLnRneiAmJiB0YXIgLXh6ZiBhd3MtZWJzLWF1dG9zY2FsZS50Z3oKLSBzaCAvb3B0L2Vicy1hdXRvc2NhbGUvYmluL2luaXQtZWJzLWF1dG9zY2FsZS5zaCAkc2NyYXRjaFBhdGggL2Rldi9zZGMgIDI+JjEgPiAvdmFyL2xvZy9pbml0LWVicy1hdXRvc2NhbGUubG9nCi0gY2QgL29wdCAmJiB3Z2V0ICRhcnRpZmFjdFJvb3RVcmwvYXdzLWVjcy1hZGRpdGlvbnMudGd6ICYmIHRhciAteHpmIGF3cy1lY3MtYWRkaXRpb25zLnRnegotIHNoIC9vcHQvZWNzLWFkZGl0aW9ucy9lY3MtYWRkaXRpb25zLW5leHRmbG93LnNoIAotIHNlZCAtaSAncytPUFRJT05TPS4qK09QVElPTlM9Ii0tc3RvcmFnZS1kcml2ZXIgYnRyZnMiK2cnIC9ldGMvc3lzY29uZmlnL2RvY2tlci1zdG9yYWdlCi0gc2VydmljZSBkb2NrZXIgc3RhcnQKLSBzdGFydCBlY3MKCi0tPT1CT1VOREFSWT09LS0="
}
```

The above template will create an instance with three attached EBS volumes.

* `/dev/xvda`: will be used for the root volume
* `/dev/xvdcz`: will be used for the docker metadata volume
* `/dev/sdc`: will be the initial volume use for scratch space (more on this below)

The `UserData` value is the `base64` encoded version of the following:

```yaml
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"

packages:
- jq
- btrfs-progs
- python27-pip
- sed
- wget

runcmd:
- pip install -U awscli boto3
- scratchPath="/var/lib/docker"
- artifactRootUrl="https://s3.amazonaws.com/aws-genomics-workflows/artifacts"
- service docker stop
- cp -au /var/lib/docker /var/lib/docker.bk  
- cd /opt && wget $artifactRootUrl/aws-ebs-autoscale.tgz && tar -xzf aws-ebs-autoscale.tgz
- sh /opt/ebs-autoscale/bin/init-ebs-autoscale.sh $scratchPath /dev/sdc  2>&1 > /var/log/init-ebs-autoscale.log
- cd /opt && wget $artifactRootUrl/aws-ecs-additions.tgz && tar -xzf aws-ecs-additions.tgz
- sh /opt/ecs-additions/ecs-additions-nextflow.sh 
- sed -i 's+OPTIONS=.*+OPTIONS="--storage-driver btrfs"+g' /etc/sysconfig/docker-storage
- service docker start
- start ecs

--==BOUNDARY==--
```

The above script installs a daemon called `aws-ebs-autoscale` which will create a BTRFS filesystem at a specified mountpoint, spread it across multiple EBS volumes, and add more volumes to ensure availbility of disk space.

In this case, the mount point for auto expanding EBS volumes is set to `/var/lib/docker` - the location of docker container data volumes.  This allows for containers used in the workflow to stage in as much data as they need without needing to bind mount a special location on the host.

The above is used to handle the unpredictable sizes of data files encountered in genomics workflows, which can range from 10s of MBs to 100s of GBs.

In addition, the launch template installs the AWS CLI via `conda`, which is used by `nextflow` to stage input and output data.

Use the command below to create the corresponding launch template:

```bash
aws ec2 \
    create-launch-template \
        --launch-template-name genomics-workflow-template \
        --launch-template-data file://launch-template-data.json
```

You should get something like the following as a response:

```json
{
    "LaunchTemplate": {
        "LatestVersionNumber": 1, 
        "LaunchTemplateId": "lt-0123456789abcdef0", 
        "LaunchTemplateName": "genomics-workflow-template", 
        "DefaultVersionNumber": 1, 
        "CreatedBy": "arn:aws:iam::123456789012:user/alice", 
        "CreateTime": "2019-01-01T00:00:00.000Z"
    }
}
```

Note the `LaunchTemplateName` value, you will need it later.

### Batch Compute Environments

AWS Batch compute environments are groupings of EC2 instance types that jobs are scheduled onto based on their individual compute resource needs.  From an HPC perspective, you can think of compute environments like a virtual cluster of compute nodes.  Compute environments can be based on either On-demand or Spot EC2 instances, where the latter enables significant savings.

You can create several compute environments to suit your needs.  Below we'll create the following:

* An "optimal" compute environment using on-demand instances
* An "optimal" compute environment using spot instances


#### Create an "optimal" on-demand compute environment

1. Go to the AWS Batch Console
2. Click on "Compute environments"
3. Click on "Create environment"
4. Select "Managed" as the "Compute environment type"
5. For "Compute environment name" type: "ondemand"
6. In the "Service role" drop down, select the `AWSBatchServiceRole` you created previously
7. In the "Instance role" drop down, select the `ecsInstanceRole` you created previously
8. For "Provisioning model" select "On-Demand"
9. "Allowed instance types" will be already populated with "optimal" - which is a mixture of M4, C4, and R4 instances.
10. In the "Launch template" drop down, select the `genomics-workflow-template` you created previously
11. Set Minimum and Desired vCPUs to 0.
 
> *INFO*
> 
>  Minimum vCPUs is the lowest number of active vCPUs (i.e. instances) your compute environment will keep running and available for placing jobs when there are no jobs queued.  Setting this to 0 means that AWS Batch will terminate all instances when all queued jobs are complete.
>
>  Desired vCPUs is the number of active vCPUs (i.e. instances) that are currently needed in the compute environment to process queued jobs.  Setting this to 0 implies that there are currently no queued jobs.  AWS Batch will adjust this number based on the number of jobs queued and their resource requirements.
> 
>  Maximum vCPUs is the highest number of active vCPUs (i.e. instances) your compute environment will launch.  This places a limit on the number of jobs the compute environment can process in parallel.

For networking, the options are populated with your account's default VPC, public subnets, and security group.  This should be sufficient for the purposes of this workshop.  In a production setting, it is recommended to use a separate VPC, private subnets therein, and associated security groups.

Optional: (Recommended) Add EC tags.  These will help identify which EC2 instances were launched by AWS Batch.  At minimum:  

* Key: "Name"
* Value: "batch-ondemand-worker"
  
Click on "Create"

#### Create an "optimal" spot compute environment

1. Go to the AWS Batch Console
2. Click on "Compute environments"
3. Click on "Create environment"
4. Select "Managed" as the "Compute environment type"
5. For "Compute environment name" type: "spot"
6. In the "Service role" drop down, select the `AWSBatchServiceRole` you created previously
7. In the "Instance role" drop down, select the `ecsInstanceRole` you created previously
8. For "Provisioning model" select "Spot"
9. In the "Spot fleet role" drop down, select the `AWSSpotFleetTaggingRole` you created previously
10. "Allowed instance types" will be already populated with "optimal" - which is a mixture of M4, C4, and R4 instances.
11. In the "Launch template" drop down, select the `genomics-workflow-template` you created previously
12. Set Minimum and Desired vCPUs to 0.

For networking, the options are populated with your account's default VPC, public subnets, and security group.  This should be sufficient for the purposes of this workshop.  In a production setting, it is recommended to use a separate VPC, private subnets therein, and associated security groups.

Optional: (Recommended) Add EC tags.  These will help identify which EC2 instances were launched by AWS Batch.  At minimum:  

* Key: "Name"
* Value: "batch-spot-worker"
  
Click on "Create"

### Batch Job Queues

AWS Batch job queues, are where you submit and monitor the status of jobs.
Job queues can be associated with one or more compute environments in a preferred order.
Multiple job queues can be associated with the same compute environment.  Thus to handle scheduling, job queues also have a priority weight as well.

Below we'll create two job queues:

 * A "Default" job queue
 * A "High Priority" job queue

Both job queues will use both compute environments you created previously.

#### Create a "default" job queue

This queue is intended for jobs that do not require urgent completion, and can handle potential interruption.
Thus queue will schedule jobs to:

1. The "spot" compute environment
2. The "ondemand" compute environment

in that order.

Because it primarily leverages Spot instances, it will also be the most cost effective job queue.

* Go to the AWS Batch Console
* Click on "Job queues"
* Click on "Create queue"
* For "Queue name" use "default"
* Set "Priority" to 1
* Under "Connected compute environments for this queue", using the drop down menu:

    1. Select the "spot" compute environment you created previously, then
    2. Select the "ondemand" compute environment you created previously

* Click on "Create Job Queue"

#### Create a "high-priority" job queue

This queue is intended for jobs that are urgent and can handle potential interruption.
Thus queue will schedule jobs to:

1. The "ondemand" compute environment
2. The "spot" compute environment

in that order.

* Go to the AWS Batch Console
* Click on "Job queues"
* Click on "Create queue"
* For "Queue name" use "highpriority"
* Set "Priority" to 100 (higher values mean higher priority)
* Under "Connected compute environments for this queue", using the drop down menu:

    1. Select the "ondemand" compute environment you created previously, then
    2. Select the "spot" compute environment you created previously

* Click on "Create Job Queue"

## Module 2 - Running Nextflow

There are a couple key ways to run Nextflow:

*  locally for both the master process and jobs
*  locally for the master process with AWS Batch for jobs
*  containerized with "Batch-Squared" Infrastructure - An AWS Batch job for the master process that creates additional AWS Batch jobs

### Local master and jobs

You can run Nextflow workflows entire on a single compute instance.  This can either be your local laptop, or a remote server like an EC2 instance.  in this workshop, your AWS Cloud9 Environment can simulate this scenario.

In a bash terminal, type the following:

```bash
nextflow run hello
```

This will run Nextflow's built-in "hello world" workflow.

### Local master and AWS Batch jobs

Genomics and life sciences workflows typically use a variety of tools that each have distinct computing resource requirements, such as high CPU or RAM utilization, or GPU acceleration.
Sometimes these requirements are beyond what a laptop or a single EC2 instance can provide.  Plus, provisioning a single large instance so that a couple of steps in a workflow can run would be a waste of computing resources.

A more cost effective method is to provision compute resources dynamically, as they are needed for each step of the workflow.
This is what AWS Batch is good at doing.

Here we'll use the AWS Resources that were created ahead of time in your account.  (These match the resources described in [Module 1](#module-1---aws-resources)).

To configure your local Nextflow installation to use AWS Batch for workflow steps (aka jobs, or processes) you'll need to know the following:

* The "default" AWS Batch Job Queue workflows will be submitted to
* The S3 path that will be used as your nextflow working directory

These parameters need to go into a Nextflow config file.
To create this file, open a bash terminal and run the following:

```bash
cd ~/environment
mkdir -p work

cd ~/environment/work
python ~/environment/nextflow-workshop/create-config.py > nextflow.config
```  

This will create a file called `~/environment/work/nextflow.config` with contents like the following:

```groovy
workDir = "s3://genomics-workflows-cfa71800-c83f-11e9-8cd7-0ae846f1e916/_nextflow/runs"
process.executor = "awsbatch"
process.queue = "arn:aws:batch:us-west-2:123456789012:job-queue/default-45e553b0-c840-11e9-bb02-02c3ece5f9fa"
aws.batch.cliPath = "/home/ec2-user/miniconda/bin/aws"
```

Now when your run the `nextflow` "hello world" example from within this `work` folder:

```bash
cd ~/environment/work
nextflow run hello
```

you should see the following output:

```text
N E X T F L O W  ~  version 19.07.0
Launching `nextflow-io/hello` [angry_heisenberg] - revision: a9012339ce [master]
WARN: The use of `echo` method is deprecated
executor >  awsbatch (4)
[54/5481e0] process > sayHello (4) [100%] 4 of 4 ✔
Hello world!

Ciao world!

Bonjour world!

Hola world!

Completed at: 12-Sep-2019 00:46:56
Duration    : 3m 1s
CPU hours   : (a few seconds)
Succeeded   : 4
```

This will be similar to the output in the previous section with the only difference being:

```
executor >  awsbatch (4)
```

which indicates that workflow processes were run remotely as AWS Batch Jobs and not on the local instance.

### Batch-Squared

Since the master `nextflow` process needs to be connected to jobs to monitor progress, using a local laptop, or a dedicated EC2 instance for the master `nextflow` process is not ideal for long running workflows.  In both cases, you need to make sure that the machine or EC2 instance stays on for the duration of the workflow, and is shutdown when the workflow is complete.  If a workflow finishes in the middle of the night, it could be hours before the instance is turned off.

The `nextflow` executable is fairly lightweight and can be easily containerized.  After doing so, you can then submit a job to AWS Batch that runs `nextflow`.  This job will function as the master `nextflow` process and submit additional AWS Batch jobs for the workflow.  Hence, this is AWS Batch running AWS Batch, or Batch-squared!

The benefit of Nextflow on Batch-squared is that since AWS Batch is managing the compute resources for both the master `nextflow` process _and_ the workflow jobs, once the workflow is complete, everything is automatically shut-down for you.

The next two sub-sections walk through how to containerize Nextflow and create an AWS Batch Job Definition to run the container.  These resources have already been created in your account for the workshop.

#### Containerizing Nextflow

Here, we'll create a `nextflow` Docker container and push the container image to a repository in Amazon Elastic Container Registry (ECR).  As part of the containerization process, we'll add an entrypoint script that will make the container "executable" and enable extra integration with AWS.

In your AWS Cloud9 environment navigate to the `nextflow-workshop` folder.  There you will find the following files:

* `Dockerfile`
* `nextflow.aws.sh`

If you do not see these files, create them with the following contents:

##### `Dockerfile`

Since the latest release of `nextflow` can be downloaded as a precompiled executable, the Dockerfile to create a container image is fairly straight-forward and replicates the steps you would do to install `nextflow` on a local system.

```Dockerfile
FROM centos:7 AS build

RUN yum update -y \
 && yum install -y \
    curl \
    java-1.8.0-openjdk \
    awscli \
 && yum clean -y all

ENV JAVA_HOME /usr/lib/jvm/jre-openjdk/

WORKDIR /opt/inst
RUN curl -s https://get.nextflow.io | bash
RUN mv nextflow /usr/local/bin

COPY nextflow.aws.sh /opt/bin/nextflow.aws.sh
RUN chmod +x /opt/bin/nextflow.aws.sh

WORKDIR /opt/work
ENTRYPOINT ["/opt/bin/nextflow.aws.sh"]
```

##### `nextflow.aws.sh`

```bash
#!/bin/bash
# $1    Nextflow project. Can be an S3 URI, or git repo name.
# $2..  Additional parameters passed on to the nextflow cli

# using nextflow needs the following locations/directories provided as
# environment variables to the container
#  * NF_LOGSDIR: where caching and logging data are stored
#  * NF_WORKDIR: where intermmediate results are stored


echo "$@"
NEXTFLOW_PROJECT=$1
shift
NEXTFLOW_PARAMS="$@"

# Create the default config using environment variables
# passed into the container
NF_CONFIG=~/.nextflow/config

cat << EOF > $NF_CONFIG
workDir = "$NF_WORKDIR"
process.executor = "awsbatch"
process.queue = "$NF_JOB_QUEUE"
aws.batch.cliPath = "/home/ec2-user/miniconda/bin/aws"
EOF

# AWS Batch places multiple jobs on an instance
# To avoid file path clobbering use the JobID and JobAttempt
# to create a unique path
GUID="$AWS_BATCH_JOB_ID/$AWS_BATCH_JOB_ATTEMPT"

if [ "$GUID" = "/" ]; then
    GUID=`date | md5sum | cut -d " " -f 1`
fi

mkdir -p /opt/work/$GUID
cd /opt/work/$GUID

# stage in session cache
# .nextflow directory holds all session information for the current and past runs.
# it should be `sync`'d with an s3 uri, so that runs from previous sessions can be 
# resumed
aws s3 sync --only-show-errors $NF_LOGSDIR/.nextflow .nextflow

# stage workflow definition
if [[ "$NEXTFLOW_PROJECT" =~ "^s3://.*" ]]; then
    aws s3 sync --only-show-errors --exclude 'runs/*' --exclude '.*' $NEXTFLOW_PROJECT ./project
    NEXTFLOW_PROJECT=./project
fi

echo "== Running Workflow =="
echo "nextflow run $NEXTFLOW_PROJECT $NEXTFLOW_PARAMS"
nextflow run $NEXTFLOW_PROJECT $NEXTFLOW_PARAMS

# stage out session cache
aws s3 sync --only-show-errors .nextflow $NF_LOGSDIR/.nextflow

# .nextflow.log file has more detailed logging from the workflow run and is
# nominally unique per run.
#
# when run locally, .nextflow.logs are automatically rotated
# when syncing to S3 uniquely identify logs by the batch GUID
aws s3 cp --only-show-errors .nextflow.log $NF_LOGSDIR/.nextflow.log.${GUID/\//.}
```

The entrypoint script does a couple of extra things:

1. It stages `nextflow` session and logging data to S3.  This is important since, running as a container on AWS Batch, this data will be deleted when the container process finishes.  Syncing this data to S3 enables use of the `-resume` flag with `nextflow`.
2. It also enables projects to be specified as an S3 URI - i.e. a bucket and folder therein where you have staged your Nextflow scripts and supporting files.

To build the container, open a bash terminal in AWS Cloud9, `cd` to the directory where the `Dockerfile` and `nextflow.aws.sh` files are and run the following command:

```bash
cd ~/environment/nextflow-workshop
docker build -t nextflow .
```

This will take about 2-3min to complete.

To push the container image to Amazon ECR:

* Create an image repository in Amazon ECR:
  
  * Go to the Amazon ECR Console
  * Do one of:
    * Click on "Get Started"
    * Expand the hamburger menu and click on "Repositories" and click on "Create Repository"
  * For repository name type
    * "mynextflow" - if you are attending an in person workshop
    * "nextflow" - if you are doing this on your own
  * Click "Create Repository"

* Push the container image to ECR
  
  * Go to the Amazon ECR Console
  * Type the name of your repository (e.g. "nextflow") into the search field
  * Select the repository
  * Click on "View Push Commands"
  * Follow the instructions in the dialog that appears in a bash console in AWS Cloud9


#### Batch Job Definition for Nextflow

To run `nextflow` as and AWS Batch job, you'll need a Batch Job Definition.  This needs to reference the following:

* the `nextflow` container image
* the S3 URI used for nextflow logs and session cache
* the S3 URI used as a nextflow `workDir`
* an IAM role for the Job that allows it to call AWS Batch and write to the S3 bucket(s) referenced above

First, create the IAM role for the job:

* Go to the IAM Console

Create a policy that allows the `nextflow` job to call AWS Batch, read-only access to all available / public S3 buckets, and write access **only** to the S3 buckets you will use for logs and workDir.

* Click on "Policies"
* Click "Create Policy"
* Select "Batch" as the service
* Under Actions > Access level:
  * Check all "List"
  * Check all "Read"
  * Under "Write" select:
    * CancelJob
    * TerminateJob
    * SubmitJob
    * DeregisterJobDefinition
    * RegisterJobDefinition
* Under Resources select "All Resources"
* Click "Review Policy"
* Name the policy "nextflow-batch-access-policy"
* Click "Create Policy"

Create a service role:

* Click on "Roles"
* Click on "Create role"
* Select "AWS service" as the trusted entity
* Choose Elastic Container Service from the larger services list
* Choose "Elastic Container Service Task" as the use case.
* Click "Next: Permissions"
* Type "S3" in the search field
* Check the box next to "AmazonS3ReadOnlyAccess"

* Type "nextflow-batch-access-policy" in the search field
* Check the box next to "nextflow-batch-access-policy" (this is the policy you created above)

You'll also need to add the policies you created in [Module - 1](#module-1---aws-resources) > [IAM Roles](#iam-roles) > [Create IAM Policies](#create-an-iam-policies) for S3 bucket access and EBS autoscaling.

* Type "bucket-access-policy" in the search field
* Check the box next to "bucket-access-policy"

* Type "nextflow-batch-access-policy" in the search field
* Check the box next to "ebs-autoscale-policy"

* Click "Next: Tags".  (adding tags is optional)
* Click "Next: Review"
* Set the Role Name to "NextflowJobRole"
* Click "Create role"

Now we have everything we need in place to create the Batch Job Definition.

* Go to the AWS Batch Console
* Click on "Job Definitions"
* Click on "Create"
* In "Job definition name", type "nextflow"
* In the "Job role" menu, select the NextflowJobRole you created above
* In "Container image", type the URI for the `nextflow` container image in ECR.
  * It should look something like: `123456789012.dkr.ecr.{region}.amazonaws.com/nextflow:latest`
* Set vCPUs = 2
* Set Memory (MiB) = 1024
* Click on "Add environment variable" and set:
  * Key = "NF_LOGSDIR"
  * Value = "s3://nextflow-workshop-abc-20190101/_nextflow/logs"
* Repeat the above for:
  * "NF_WORKDIR"="s3://nextflow-workshop-abc-20190101/_nextflow/logs"
  * "NF_JOB_QUEUE"="default-job-queue"
* Click "Create Job Definition"

#### Submitting a Nextflow workflow

To submit a Nextflow workflow - e.g. the `nextflow` "hello" workflow to the Batch-squared architecture:

* Go to the AWS Batch Console
* Click "Jobs"
* Click "Submit job"
* Set "Job name" as "nf-workflow-hello"
* For "Job definition" select "nextflow:1"
* For "Job queue" select "highpriority".  It is important that the `nextflow` master process not be interrupted for the duration of the workflow.
* In the "Command" field type "hello".  Text here is the same as what would be sent as `...` arguments to a `docker run -it nextflow ...` command.
* Click "Submit job"

To monitor the status of the workflow:

* Go to the AWS Batch Console
* Click on "Dashboard"

You should see 1 job advance from "SUBMITTED" to "RUNNING" in the "highpriority" queue row.

Once the job enters the "RUNNING" state, you should see 4 additional jobs get submitted to the "default" queue.  These are the processes defined in the workflow.

When jobs are complete (either FAILED or SUCCEEDED) you can check the logs generated.

You can also use the AWS CLI to submit workflows.  For example, to run the `nextflow` "hello" workflow, type the following into a bash terminal:

```bash
aws batch submit-job \
  --job-definition nextflow \
  --job-name nf-workflow-hello \
  --job-queue highpriority \
  --container-overrides command=hello
```

You should get a response like:

```json
{
    "jobName": "nf-workflow-hello", 
    "jobId": "93e2b96e-9bee-4d67-b935-d31d2c12173a"
}
```

which contains the AWS Batch JobId you can use to track progress of the workflow.  To do this, you can use the Jobs view in the AWS Batch Console.

You can also simplify the command by wrapping it in a bash script that gather's key information automatically.

```bash
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
```

Output from this script would look like this:

```bash
./submit-workflow.sh hello hello

# aws batch submit-job --region us-west-2 --job-definition nextflow --job-name nf-workflow-hello --job-queue highpriority-45e553b0-c840-11e9-bb02-02c3ece5f9fa --container-overrides command='hello'
# {
#     "jobName": "nf-workflow-hello", 
#     "jobId": "ecb9a154-92a9-4b9f-99d5-f3071acb7768"
# }
```

#### Run a realistic demo workflow

Here is the source code for a demo workflow that converts FASTQ files to VCF using bwa-mem, samtools, and bcftools.  It uses a public data set that has been trimmed and only calls variants on chromosome 21 so that the workflow completes in about 5-10 minutes.

https://github.com/wleepang/demo-genomics-workflow-nextflow

To submit this workflow you can use the script you created above:

```bash
./submit-workflow.sh demo \
  wleepang/demo-genomics-workflow-nextflow \
  --output s3://nextflow-workshop-abc-20190101
```

> NOTE
> 
> You need to specify a bucket that you have write access to via the `--output` parameter.  Otherwise, the workflow will fail.

You can check the status of the workflow via the command line:

```bash
aws batch describe-jobs --jobs $jobid | jq -r .jobs[].status
```

You can also check the log output from the workflow:

* Go to the AWS Batch Console
* Click on "Jobs"
* Select the "highpriority" queue
* Click on "RUNNING" ()
* Click on the Job that matches the JobId above
* Scroll to the bottom of the Job Info and click on "View logs for the most recent attempt in the CloudWatch console".

You should now be in CloudWatch Logs looking at the log stream for the AWS Batch job running your nextflow workflow.

#### Run an NF-Core wokflow

There are many example workflows available via [NF-Core](https://nf-core.re).  These are workflows that are developed using best practices from the Nextflow community.  They are also good starting points to run common analyses such as ATACSeq or RNASeq.

The steps below runs the nf-core/rnaseq workflow against data from the 1000 Genomes dataset.

You can do this directly from the command line with:

```bash
./submit-workflow.sh rnaseq \
  nf-core/rnaseq \
    --reads 's3://1000genomes/phase3/data/HG00243/sequence_read/SRR*_{1,2}.filt.fastq.gz' \
    --genome GRCh37 \
    --skip_qc
```

There are many parameters for this workflow and setting time all via the command line can be cumbersome.  For more complex configuration, it is best to package the container overrides into a JSON file.  To do this for the above workflow configuration:

Create a json file called `rnaseq.parameters.json` with the following contents:

```json
{
    "command": [
      "nf-core/rnaseq",
      "--reads", "'s3://1000genomes/phase3/data/HG00243/sequence_read/SRR*_{1,2}.filt.fastq.gz'",
      "--genome", "GRCh37",
      "--skip_qc"
    ]
}
```

Submit the workflow using:

```bash
./submit-workflow.sh rnaseq file://rnaseq.parameters.json
```

## Module 3 - Automation

In [Module 1](#module-1---aws-resources) and [Module 2](#module-2---running-nextflow) you created the infrastructure you needed to run Nextflow on AWS from scratch.  If you need to reproduce these resources in another account or create multiple versions in the same account, you don't need to do so by hand each time.

All of what you created can be automated using AWS Cloudformation which allows you to describe your infrastructure as code using Cloudformation templates.

You can use the CloudFormation templates available at the link below to setup this infrastructure in your own environment.

[Genomics Workflows on AWS - Nextflow Full Stack](https://docs.opendata.aws/genomics-workflows/orchestration/nextflow/nextflow-overview/#full-stack-deployment)

The source code is also open source and available on Github - so you can customize the architecture to suit special use cases.

