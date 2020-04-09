# Module 0 - Cloud9 Environment Setup

AWS Cloud9 is a cloud-based integrated development environment (IDE) that lets you write, run, and debug your code with just a browser. It includes a code editor, debugger, and terminal. Cloud9 comes prepackaged with essential tools for popular programming languages, including JavaScript, Python, PHP, and more, so you don’t need to install files or configure your development machine to start new projects.

We'll use Cloud9 in this workshop to ensure that all participants have the same development and execution environment.  It will also serve as a stand-in for a common "local" environment.

## Start your Cloud9 IDE

* Go to the AWS Cloud9 Console
* Go to **Your Environments**
* Select the **"genomics-workflows"** environment
* Click on the **Open IDE** button

This will launch AWS Cloud9 in a new tab of your web browser.  The IDE takes about 1-2min to spin up.

## Using an IAM role with Cloud9
Cloud9 normally manages IAM credentials dynamically. This isn’t currently compatible with the `nextflow` CLI, so we will disable it and rely on an IAM instance role instead.

Associate an administrative role to the EC2 Instance used by Cloud9:

```bash
aws ec2 associate-iam-instance-profile \
      --iam-instance-profile Name=NextflowAdminInstanceRole \
      --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id)

```

Disable Cloud9's credentials management:

* Goto to your Cloud9 IDE and in the Menu go to **AWS Cloud9 > Preferences**.  This will launch a new "Preferences" tab.
* Select **AWS SETTINGS**
* Turn off **AWS managed teporary credentials**
* Close the "Preference" tab
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

## Install and Configure Dependencies

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

Make helper scripts executable:

```bash
cd ~/environment/nextflow-workshop
chmod +x *.py *.sh
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

If you don't, another way to verify that you have Nextflow correctly installed is:

```bash
which nextflow

# the above should return:
# ~/bin/nextflow
```