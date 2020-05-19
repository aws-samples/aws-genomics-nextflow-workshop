# Module 0 - SageMaker Environment Setup

Amazon SageMaker is a fully managed service that provides every developer and data scientist with the ability to build, train, and deploy machine learning (ML) models quickly.  It allows you to explore data and develop model code using familiar tools and environments like Jupyter notebooks.

We'll use Sagemaker's JupyterLab environment in this workshop to ensure that all participants have the same development and execution environment.  It will also serve as a stand-in for a common "local" environment.

## Start your JupyterLab

* Go to the Amazon SageMaker Console
* Go to **Notebook / Notebook instances**
* Search for the **"owner-nextflow-genomics"** instance
* Click on the **Open JupyterLab** link

This will launch JupyterLab in a new tab of your web browser.

## Verify your IAM role
The notebook instance will have been created by the Cloudformation templates used to provision resources for this workshop. It should have an IAM execution role attached to it that will allow access to the appropriate resources.

Verify that this role is correct:

* Goto to your JupyterLab instance and in the Menu go to **File > Terminal**.  This will launch a new "Terminal" tab.
* Verify the applied credentials:

```bash
aws sts get-caller-identity

# Output should look like this:
# {
#     "Account": "123456789012", 
#     "UserId": "AROA1SAMPLEAWSIAMROLE:i-01234567890abcdef", 
#     "Arn": "arn:aws:sts::123456789012:assumed-role/Nextflow-JupyterRole-1234567890ABCD/SageMaker"
# }
```

If your output does not match the above **DO NOT PROCEED**.  Ask for assistance.

## Install and Configure Dependencies

Install Nextflow:

```bash
curl -s https://get.nextflow.io | bash
sudo mv ./nextflow /usr/local/bin
```

When the above is complete you should see something like the following:

```text
      N E X T F L O W
      version 19.07.0 build 5106
      created 27-07-2019 13:22 UTC 
      cite doi:10.1038/nbt.3820
      http://nextflow.io


Nextflow installation completed.
```
