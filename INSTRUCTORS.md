# Instructor Notes

This workshop is intended to be run using the AWS Event Engine (EE) with two EE modules (pre-built infrastructure):

* Cloud9: a common environment for participants to use for interacting with their provided AWS accounts with the command line.
* Nextflow "All-in-One": all resources needed to run a containerized version of Nextflow using AWS Batch.

The above are created using Cloudformation templates in `cfn/`:

* Cloud9: `cfn/cloud9.cfn.yaml`
* Nextflow: `cfn/nextflow/nextflow-aio.template.yaml`

The Nextflow template uses nested templates which are also provided in `cfn/`.  They have also been uploaded to the S3 URI `pwyming-demos-templates/nextflow-workshop/` with public read ACLs.  You shouldn't have to change any of the nested templates, unless you want to customize them to suit specific needs.

## Testing

The stacks used in this workshop have been designed to build/run using only default parameters (the EE requires it).  To test in your own accounts, you should do the same with a couple exceptions as noted below.

### Cloud9

Cloud9 environments require an owner which can be either an IAM user or an Assumed Role.

A Cloud9 environment created by Cloudformation without specifying an owner will subsequently be owned by the user that ran Cloudformation.  If participants are using a different user or assumed-role, they will therefore not have access to the Cloud9 environment.

The Cloud9 template defaults to using the Assumed Role "TeamRole/MasterKey" as the owner, which is the role that participants using an EE based workshop will use.

To test the Cloud9 environment in your own account, you need to set the `EnvironmentOwnerType` to `user` and set the `EnvironmentOwnerName` to an IAM user you can login as.
