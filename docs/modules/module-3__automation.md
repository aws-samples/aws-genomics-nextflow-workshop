# Module 3 - Automation

In [Module 1](./module-1__aws-resources.md) and [Module 2](./module-2__running-nextflow.md) you created the infrastructure you needed to run Nextflow on AWS from scratch.  If you need to reproduce these resources in another account or create multiple versions in the same account, you don't need to do so by hand each time.

All of what you created can be automated using AWS Cloudformation which allows you to describe your infrastructure as code using Cloudformation templates.

You can use the CloudFormation templates available at the link below to setup this infrastructure in your own environment.

[Genomics Workflows on AWS - Nextflow Full Stack](https://docs.opendata.aws/genomics-workflows/orchestration/nextflow/nextflow-overview/#full-stack-deployment)

The source code is also open source and available on Github - so you can customize the architecture to suit special use cases.  Also, if you have suggestions on how to improve the infrastructure feel free to submit a pull request!
