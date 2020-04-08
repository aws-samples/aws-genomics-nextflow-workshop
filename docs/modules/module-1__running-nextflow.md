# Module 1 - Running Nextflow

There are a couple key ways to run Nextflow:

*  locally for both the master process and jobs
*  locally for the master process with AWS Batch for jobs
*  containerized with "Batch-Squared" Infrastructure - An AWS Batch job for the master process that creates additional AWS Batch jobs

![ways to run nextflow](../images/running-nextflow.png)

## Local master and jobs

You can run Nextflow workflows entire on a single compute instance.  This can either be your local laptop, or a remote server like an EC2 instance.  In this workshop, your AWS Cloud9 Environment simulates this scenario.

In a bash terminal, type the following:

```bash
nextflow run hello
```

This will run Nextflow's built-in "hello world" workflow.

## Local master and AWS Batch jobs

Genomics and life sciences workflows typically use a variety of tools that each have distinct computing resource requirements, such as high CPU or RAM utilization, or GPU acceleration.
Sometimes these requirements are beyond what a laptop or a single EC2 instance can provide.  Plus, provisioning a single large instance so that a couple of steps in a workflow can run would be a waste of computing resources.

A more cost effective method is to provision compute resources dynamically, as they are needed for each step of the workflow.
This is what AWS Batch is good at doing.

Here we'll use the AWS Resources that were created ahead of time in your account.  (These resources are described in more detail in [Module 2](./module-2__aws-resources.md)).

!!! important
    Run the following to "pre-warm" your AWS Batch compute environments.  This sets each of the compute environments with a Minimum vCPU count > 0 so that it has compute resources immediately available so that queued jobs get scheduled faster.

        cd ~/environment/nextflow-workshop
        ./prewarm.sh
    
    When Mininum vCPUs is set to 0, AWS Batch automatically scales down (terminates) all instances when there are no longer jobs queued.  It can take up to 10min for new vCPUs to spin up after a scale down event.
        
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

## Batch-Squared

![batch-squared](../images/submitting-workflows-batch-squared.png)

Since the master `nextflow` process needs to be connected to jobs to monitor progress, using a local laptop, or a dedicated EC2 instance for the master `nextflow` process is not ideal for long running workflows.  In both cases, you need to make sure that the machine or EC2 instance stays on for the duration of the workflow, and is shutdown when the workflow is complete.  If a workflow finishes in the middle of the night, it could be hours before the instance is turned off.

The `nextflow` executable is fairly lightweight and can be easily containerized.  After doing so, you can then submit a job to AWS Batch that runs `nextflow`.  This job will function as the master `nextflow` process and submit additional AWS Batch jobs for the workflow.  Hence, this is AWS Batch running AWS Batch, or Batch-squared!

The benefit of Nextflow on Batch-squared is that since AWS Batch is managing the compute resources for both the master `nextflow` process _and_ the workflow jobs, once the workflow is complete, everything is automatically shut-down for you.

### Submitting a Nextflow workflow

Let's submit a Nextflow workflow to the Batch-squared architecture, e.g. the `nextflow run hello` for the "hello" workflow :

1. Go to the AWS Batch Console
2. Click "Jobs"
3. Click "Submit job"
4. Set "Job name" as "nf-workflow-hello"
5. For "Job definition" select "nextflow:1"
6. For "Job queue" select "highpriority".  It is important that the `nextflow` master process not be interrupted for the duration of the workflow
7. In the "Command" field type "hello".  Text here is the same as what would be sent as `...` arguments to a `docker run -it nextflow ...` command
8. Click "Submit job".

To monitor the status of the workflow, navigate back to the AWS Batch Console and click on "Dashboard" in the left sidebar.

You should see 1 job advance from "SUBMITTED" to "RUNNING" in the "highpriority" queue row.

Once the job enters the "RUNNING" state, you should see 4 additional jobs get submitted to the "default" queue.  These are the processes defined in the workflow.

When jobs are complete (either FAILED or SUCCEEDED) you can check the logs generated.

You can also use the AWS CLI to submit workflows.  For example, to run the `nextflow` "hello" workflow, type the following into a bash terminal:

```bash
HIGHPRIORITY_JOB_QUEUE=$(aws --region $AWS_REGION batch describe-job-queues | jq -r .jobQueues[].jobQueueName | grep highpriority)
aws batch submit-job \
  --job-definition nextflow \
  --job-name nf-workflow-hello \
  --job-queue $HIGHPRIORITY_JOB_QUEUE \
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

#### Getting workflow logs

AWS Batch jobs automatically record logs to CloudWatch Logs.  What is recorded depends on the container called by the job, but generally this is anything that is sent to STDOUT.  These logs are helpful if you want to check on the runtime details of your workflow or inspect error messages if any of the processes in your workflow fails.

To get the logs for an entire workflow:

1. Go to the AWS Batch Console
2. Click on "Jobs"
3. Select "highpriority" in the Queue dropdown
4. Select either "running", "succeeded", or "failed" for the job status table
5. Click on the Job ID of the workflow job you are interested in
6. Scroll to the bottom of the sidebar that opens and click on the link under the "CloudWatch logs" section.  This will open a new tab with the CloudWatch Logstream for the workflow.

!!! note
    To get the logs for a specific job in a workflow, you repeat the above steps, but look for jobs in the "default" job queue instead, as this is where `nextflow` will submit jobs for workflow processes (unless specifically overriden).

### Run a realistic demo workflow

Here is the source code for a demo workflow that converts FASTQ files to VCF using bwa-mem, samtools, and bcftools.  It uses a public data set that has been trimmed and only calls variants on chromosome 21 so that the workflow completes in about 5-10 minutes.

[https://github.com/wleepang/demo-genomics-workflow-nextflow](https://github.com/wleepang/demo-genomics-workflow-nextflow)

To submit this workflow you can use the script you created above:

```bash
./submit-workflow.sh demo \
  wleepang/demo-genomics-workflow-nextflow
```

You can check the status of the workflow via the following command line where you replace "JOBID" with the "jobId" output from above:

```bash
aws batch describe-jobs --jobs JOBID --query 'jobs[0].status'
```

#### Run a different version of the workflow

When calling a workflow from a Git repository (such as GitHub), you can also run different versions of the workflow by referencing tagged commits or branches.

The following will call a version of the demo workflow that uses dynamic parallelism to call variants on chromosomes 19-22 simultaneously.

```bash
./submit-workflow.sh demo-parallel \
  wleepang/demo-genomics-workflow-nextflow -r dynamic-parallelism --chromosomes chr19,chr20,chr21,chr22
```

When this workflow reaches the variant call step, it will spawn 4 simultaneous jobs - one for each `chr##` provided to the `--chromosomes` argument.

#### Resuming a workflow

If your workflow stops midway through, you can restart it from where you left off with the `-resume` flag.  This is useful when developing a workflow, allowing you to "cache" the results of long running steps.

```bash
./submit-workflow.sh demo \
  wleepang/demo-genomics-workflow -resume (<session-name>|<session-id>)
```

You can get the session-name or session-id from the logs for a previous run of the workflow.  The "resumed" workflow should complete in only a few seconds.

### Run an NF-Core workflow

There are many example workflows available via [NF-Core](https://nf-co.re).  These are workflows that are developed using best practices from the Nextflow community.  They are also good starting points to run common analyses such as ATACSeq or RNASeq.

The steps below runs the nf-core/rnaseq workflow against data from the 1000 Genomes dataset.

You can do this directly from the command line with:

```bash
./submit-workflow.sh rnaseq \
  nf-core/rnaseq \
    --reads "s3://pwyming-demo-data/secondary-analysis/fastq/demo/NIST7035_R{1,2}_trim_samp-0p1.fastq.gz" \
    --genome GRCh37 \
    --skip_qc
```

There are many parameters for this workflow, and setting all via the command line can be cumbersome.  For more complex configurations, it is best to package the container overrides into a JSON file.  To do this for the above workflow configuration:

Create a json file called `rnaseq.parameters.json` with the following contents:

```json
{
    "command": [
      "nf-core/rnaseq",
      "--reads", "'s3://pwyming-demo-data/secondary-analysis/fastq/demo/NIST7035_R{1,2}_trim_samp-0p1.fastq.gz'",
      "--genome", "GRCh37",
      "--skip_qc"
    ]
}
```

Submit the workflow using:

```bash
./submit-workflow.sh rnaseq file://rnaseq.parameters.json
```

This workflow takes approximately 20min to complete.
