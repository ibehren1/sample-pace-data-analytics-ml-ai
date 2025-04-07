> [!NOTE]
> This repository is maintained by AWS FSI PACE team. While it has been thoroughly tested internally there might be things that we still need to polish. If you encounter any problems with the deployment process please open a GitHub Issue in this repository detailing your problems and our team will address them as soon as possible.

# Solutions Deployment Guide 

## Table of Contents
- [Pre-requisites](#deployment-pre-requisite)
    - [Packages](#packages)
    - [AWS CLI setup](#aws-cli-setup)
    - [Clone the code base](#clone-the-code-base)
    - [Environment setup](#environment-setup)
- [Deployment steps](#deployment-steps)
- [Troubleshooting](#troubleshooting)

## Deployment Pre-requisite

### Packages

In order to execute this deployment, please ensure you have installed the following packages on the machine from which you're deploying the solution:
* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

*Note: Make sure that the latest AWS CLI version is installed. If not, some functionalities won't be deployed correctly.*
* [Terraform >= 1.8.0](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
* [Git CLI](https://git-scm.com/downloads)
* [make](https://www.gnu.org/software/make/)
* [jq](https://stedolan.github.io/jq/)


### Clone the code base

1. Open your local terminal, go to the directory in which you wish to download the Nexus solution using `cd`
2. Run the following command to download codebase into your local directory:

`git clone https://github.com/aws-samples/sample-pace-data-analytics-ml-ai.git` 

3. From your terminal, go to the root directory of the Nexus codebase using:

 `cd sample-pace-data-analytics-ml-ai`

### Environment setup

#### Input variable names used in the prototype and their meanings

```
# The application name that is used to name resources
# It is best to use a short value to avoid resource name length limits
# Example: nexus
APP_NAME 

# 12 digit AWS account ID to deploy resources to
AWS_ACCOUNT_ID 

# AWS region used as the default for AWS CLI commands
# Example: us-east-1
AWS_DEFAULT_REGION 

# The environment name that is used to name resources and to determine
# the value of environment-specific configurations.
# It is best to use a short value to avoid resource name length limits
# Select environment names that are unique. 
# Examples: quid7, mxr9, your initials with a number
ENV_NAME 

# Primary AWS region to deploy application resources to
# Example: us-east-1
AWS_PRIMARY_REGION 

# Secondary AWS region to deploy application resources to
# Example: us-west-2
AWS_SECONDARY_REGION 

# The name of the S3 bucket that holds Terraform state files
TF_S3_BACKEND_NAME 

```
<br>

Environment Setup Steps:

1) **Deployment Role**: Use AWS CLI to login to the account you wish to deploy to, using a deployment role with sufficient privileges to deploy the solution, preferably using the admin role or power user role or an equivalent role with sufficient privileges.

To setup your aws-cli with deployment role credentials run the following command:

```
aws configure
```

Alternatively, you can manually modify the following files:

`~/.aws/config`

`~/.aws/credentials`

Alternatively, you can manually initialize the terminal with STS credentials for the role, by obtaining temporary STS credentials from your administrator. 

```
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```

2. **Deployment Role as LakeFormation Admin**: Please add the deployment role as an "Administrator" in Lakeformation using following steps. This will allow you to successfully configure LakeFormation grants through make targets. 
  - Open AWS LakeFormation service
  - Click on "Administration -> Administrative roles and tasks" in left navigation panel
  - Click on "Manage administrators" button
  - Select "Data lake administrator" radio button  
  - Select the role from "IAM users and roles" drop down
  - Select "Confirm" button.  

3) **Initialization**: From your terminal, go to the root directory of the Nexus codebase and execute the following command. 
This command will run a wizard that will ask you to provide a value for all of the configuration settings documented above. 
It will perform a search/replace on the project files so that they use the values you provide.

```
make init
```

4) **Set Up Terraform Backend**: Execute the following command to set up S3 buckets to store the project's Terraform state.

```
make deploy-tf-backend-cf-stack
```

## Deployment Steps

The Makefile contains a "deploy-all" target, but we strongly recommend tha you "**DO NOT**" use this make target. We do not recommend deploying the solution in one go. This is due to the time needed for some make targets to initialize, warm-up and execute correctly. For example, job schedulers need time to properly set up their triggers. Also some make targets have linear dependency on other make targets. Deploying it in one go will likely cause configuration errors since some deployed make targets may not be fully functional yet and thus, not ready to be used.

Therefore, we recommend deploying the make targets incrementally, one make target at a time,  to allow each make target to execute successfully and be fully operational before the next make target is executed:
1. Deploy each make target one at a time
2. Wait for each make target to complete 
3. Verify that the make target is fully operational
4. Only then proceed to the next make target

The solution consists of a number of modules. Each module consists of a number of make targets. Please deploy the modules in the order mentioned below (just skip "Billing Data Lake - CUR" module, which you will execute after 24 hours). Each module has a make target, ex: deploy-foundation. Please "**DO NOT**" invoke the make target for a module. Instead invoke individual make targets under each module in the order they are mentioned, waiting for each make target to complete successfully before moving to the next make target. 

You will need to deploy the following modules in order to deploy the whole solution. 

| Order | Module                                    |
|-------|-------------------------------------------|
| 1     | Foundation                                |
| 2     | IAM Identity Center                       |
| 3     | Sagemaker Domain                          | 
| 4     | Sagemaker Projects                        | 
| 5     | Glue Iceberg Jar File                     | 
| 6     | Lake Formation                            | 
| 7     | Athena                                    |
| 8     | Data Lakes                                |
| 9     | Billing Data Lake - Static                | 
| 10    | Billing Data Lake - Dynamic               | 
| 11    | Billing Data Lake - CUR (After 24 hours)  | 
| 12    | Inventory Data Lake - Static              | 
| 13    | Inventory Data Lake - Dynamic             | 
| 14    | Splunk Data Lake                          | 
| 15    | Sagemaker Project Configuration           | 
| 16    | Datazone Domain and Projects              | 
| 17    | Quicksight Subscription                   | 
| 18    | Quicksight Visualization                  |
| 19    | Customer Data Lineage                     |
---

## Prep1: Set up Admin Role in Makefile

- Open Makefile in root folder
- Line #6 of the make file has a constant called "ADMIN_ROLE"
- Please specify the name of the IAM role you will use to login to AWS management console. This role will be granted lake formation access to the Glue databases, so that you can execute queries against the Glue databases using the Athena console. 

## Prep2: Delete "default" Glue Database

Certain Glue Jobs or EMR Jobs may fail if "default" Glue database exists. Please note that the "default" Glue database may also get created automatically, when you execute certain glue jobs. If you notice an error, either in a Glue job or an EMR job, related to a specific role not having permissions to "default" glue database, then please delete the "default" Glue database if it exists following the steps outlined above. 

```
make grant-default-database-permissions 
make drop-default-database
```

## 1. **Foundation**

The foundation module deploys the foundational resources, such as KMS Keys, IAM Roles and S3 Buckets that other modules need. We are provisioning KMS Keys and IAM Roles in a separate module and passing them as parameters to other modules, as in many customer organizations the central cloud team provisions these resources and allows the application teams to use these resources in their applications. We recommend that you review the IAM roles in foundation module with your cloud infrastructure team and cloud security team, update them as necessary, before you provision them in your environment. You **MUST** deploy the make targets for this module first before deploying make targets for other modules. Please execute the following make targets in order. 

#### To deploy the module:
```
make deploy-kms-keys
make deploy-iam-roles
make deploy-buckets
```

| Target          | Result                                    | Verification                                                                           |  
|------------------|--------------------------------------------|-----------------------------------------------------------------------------------| 
| deploy-kms-keys  | Provisions KMS keys used by different AWS services | Following KMS keys and aliases are created: <br> 1. {app}-{env}-secrets-manager-secret-key <br> 2. {app}-{env}-systems-manager-secret-key <br> 3. {app}-{env}-s3-secret-key <br> 4. {app}-{env}-glue-secret-key <br> 5. {app}-{env}-athena-secret-key <br> 6. {app}-{env}-event-bridge-secret-key <br> 7. {app}-{env}-cloudwatch-secret-key <br> 8. {app}-{env}-datazone-secret-key <br> 9. {app}-{env}-ebs-secret-key                        | 
| deploy-iam-roles | Provisions IAM roles used by different modules              | Following IAM roles are created: <br> 1. {app}-{env}-glue-role <br> 2. {app}-{env}-lakeformation-service-role <br> 3. {app}-{env}-eventbridge-role <br> 4. {app}-{env}-lambda-billing-trigger-role <br> 5. {app}-{env}-lambda-inventory-trigger-role <br> 6. {app}-{env}-splunk-role <br>  7. {app}-{env}-event-bridge-role <br> 8. {app}-{env}-sagemaker-role <br>  9. {app}-{env}-datazone-domain-execution-role <br> 10. {app}-{env}-quicksight-service-role   
| deploy-buckets   | Deploy S3 buckets needed by different modules                         | Following S3 buckets are created: <br> 1. {app}-{env}-glue-scripts-primary <br> 2. {app}-{env}-glue-scripts-primary-log <br> 3. {app}-{env}-glue-scripts-secondary <br> 4. {app}-{env}-glue-scripts-secondary-log  <br> 5. {app}-{env}-glue-jars-primary <br> 6. {app}-{env}-glue-jars-primary-log <br> 7. {app}-{env}-glue-jars-secondary <br> 8. {app}-{env}-glue-jars-secondary-log  <br> 9. {app}-{env}-glue-spark-logs-primary <br> 10. {app}-{env}-glue-spark-logs-primary-log <br> 11. {app}-{env}-glue-spark-logs-secondary <br> 12. {app}-{env}-glue-spark-logs-secondary-log <br> 13. {app}-{env}-glue-temp-primary <br> 14. {app}-{env}-glue-temp-primary-log <br> 15. {app}-{env}-glue-temp-secondary <br> 16. {app}-{env}-glue-temp-secondary-log <br> 17. {app}-{env}-athena-output-primary <br> 18. {app}-{env}-athena-output-primary-log <br> 19. {app}-{env}-athena-output-secondary <br> 20. {app}-{env}-athena-output-secondary-log <br> 21. {app}-{env}-amazon-sagemaker-{account_id}-primary <br> 22. {app}-{env}-amazon-sagemaker-{account_id}-primary-log <br> 23. {app}-{env}-amazon-sagemaker-{account_id}-secondary <br> 24. {app}-{env}-amazon-sagemaker-{account_id}-secondary-log <br> 25. {app}-{env}-smus-project-cfn-template-primary <br> 26. {app}-{env}-smus-project-cfn-template-primary-log <br> 27. {app}-{env}-smus-project-cfn-template-secondary <br> 28. {app}-{env}-smus-project-cfn-template-secondary-log            |  
---

## 2. **IAM Identity Center**

The IAM Identity Center module deploys an IAM Identity Center. It is recommended that you deploy an organization level Identity Center. Alternately, you can choose to deploy an account level Identity Center if you prefer. 

#### Before deploying this step: 

**Important Note**: Only one instance can be deployed across all regions, and it must be either Organization-level or Account-level.
- [Review AWS Documentation](https://docs.aws.amazon.com/singlesignon/latest/userguide/identity-center-instances.html) to understand the differences between Organization-level versus Account-level Identity Center

Before configuring Identity Center using make targets:
1. Enable the desired version of Identity Center (Organization-level or Account-level) manually on the IAM Identity Center Console
- Navigate to IAM Identity Center in the console
- For organization-level: Select "Enable" > *Enable IAM Identity Center with AWS Organizations* > "Enable"
- For account-level: Select "Enable" > *Enable an account instance of IAM Identity Center* > "Enable"
2. Ensure no existing Identity Center instance is running
- Must delete previous instance before deploying new one
- Currently no programmatic support is available to enable Identity Center through IaC



#### To deploy the organization level identity center configuration:

```
make deploy-idc-org
```

| Target        | Result                                                                                      | Verification |  
|----------------|----------------------------------------------------------------------------------------------|--------
| deploy-idc-org | Provisions IAM Identity Center groups, users, and permission sets (Organization-level) | Following groups are created in Identity Center: <br> 1. Admin  <br> 2. Domain Owner  <br> 3. Project Owner <br> 4. Project Coordinator <br> <br> Following users are created in Identity Center: <br> 1. chris-bakony-admin@example.com <br> 2. ann-chouvey-downer@example.com <br> 3. lois-lanikini-powner@example.com <br> 4. ben-doverano-contributor@example.com
| deploy-idc-acc | Deploy IAM Identity Center groups, users (Account-level)                           |Following groups are created in Identity Center: <br> 1. Admin  <br> 2. Domain Owner  <br> 3. Project Owner <br> 4. Project Coordinator <br> <br> Following users are created in Identity Center: <br> 1. chris-bakony-admin@example.com <br> 2. ann-chouvey-downer@example.com <br> 3. lois-lanikini-powner@example.com <br> 4. ben-doverano-contributor@example.com|
---

#### Two Factor Authentication: 

IAM Identity Center is configured to require two-factor authentication. We recommend you retain the two factor authentication configured. In case, you would like disable two-factor athentication in your sandbox account to make it easy for you to login to Sagemaker Unified Studio without requirement two-factor authentication, you can implement following steps. 

1. Click on "Settings" in left navigation panel
2. Click on "Athentication" tab
3. Click "Configure" buttton in "Multi-factor athentication" section
4. Click on "Never" in "MFA Settings"
5. Click on "Save changes" button

We do not recommend disabling multi-factor authentication. However, if you used the above steps to make it easy for you to explore the Nexus solution in a Sandbox account, we recommend that you enable multi-factor authentication once you have completed exploring Nexus solution. We do not recommend disabling multi-factor authentication in develpment, test or production environment. 

#### Setting Password for Users: 

Execute the following steps to set up passwords for the users created in IAM Identity Center.

1. Click on "User" in left navigation panel
2. For each "User" in the list do the following
3. Click on the "Username" to go to the page for the user
4. Click on "Reset password" on top right
5. Selct the check box "Generate a one-time password and share the password with the user"
6. Click on "Reset password" button
7. It will show "One-time Password" window
8. Click on the square on left of the "one-time password" to copy the password to clipboard
9. Store the username and the one-time password in a file using your favorite editor. You will need this username and one-time password to login to Sagemaker and Datazone. 

#### Useful Command to Delete a Previously Congifured Identity Center Instance (Don't Need to Execute the Following Commands): 

If you need to delete a previously deployed Organization-level instance:
```
   aws organizations delete-organization
```  
To delete Account-level Instance:
```
   # retrieve the instance ARN
   aws sso-admin list-instances
   
   # delete the account-level instance using retrieved ARN    
   aws sso-admin delete-instance --instance-arn arn:aws:sso:<region>:<account-id>:instance/<instance-id>
```

## 3. **Sagemaker Domain**

This module deploys a Sagemaker Domain for SageMaker Unified Studio, enabling relevant blueprints, and creating project profiles with relevant blueprints.

#### To deploy the module:

```
make deploy-domain-prereq
make deploy-domain
```

| Target              | Result                         | Verification                              |  
|---------------------|--------------------------------|--------------------------------------|
| deploy-domain-prereq | Deploy Pre-requisite for Domain | Following VPC is created for Sagemaker <br> 1. sagemaker-unified-studio-vpc   | 
| deploy-domain        | Deploy Domain                   | Following Sagemaker resources are created <br> 1. Sagemaker domain called *Corporate* <br> 2. Sagemaker blueprints are enabled under *Corporate* domain <br> 3. Three Sagemaker project profiles are configured under *Corporate* domain  <br> 4. Login to Sagemaker Unified Studio for *Corporate* domain using various user credentials created in *IAM Identity Center* section and confirm that you are able to open the domain. When you login to Sagemaker Unified Studio, it will be ask you to enter usename and one-time password you had created in the *IAM Identity Center* and it will ask you change the password. Please use a password with letter, numbers and special charaters and store the password in a file using your favorite editor.| 
---

## 4. **Sagemaker Projects**

This module deploys two Sagemaker projects, one for **Producer** and one for **Consumer**. When you execute the "deploy-producer-project"  or "deploy-consumer-project" make target, it will launch 4 cloud formation stacks for each project one after other. After executing the "deploy-producer-project" make target, please open Cloud Formation console and monitor the 4 cloud formation stacks get created and completed. Only then, proceed to execute the "deploy-consumer-project" make target and monitor the 4 cloud formation stacks get created and completed. Only then, proceed to execute the remaining 2 make targets "extract-producer-info" and "extract-consumer-info". 

#### To deploy the module:

```
make deploy-project-prereq
make deploy-producer-project (wait for 4 cloud formation stacks to complete)
make deploy-consumer-project (wait for 4 cloud formation stacks to complete)
make extract-producer-info
make extract-consumer-info
```

| Target               | Result                                 | Verification                              | 
|-----------------------|-----------------------------------------|--------------------------------------|
| deploy-project-prereq | Provisions Pre-requisites for Projects        | Provisions Sagemaker foundational resources   | 
| deploy-producer-project       | Provisions Producer Project                          | Provisions following Sagemaker projects: <br> 1. Producer <br> 2. Login to Sagemaker Unified Studio using "Project Owner" user with username containing "powner" and confirm that you see the producer project and you can open it  | deploy-consumer-project       | Provisions Consumer Project                          | Provisions following Sagemaker projects: <br> 1. Consumer <br> 2. Login to Sagemaker Unified Studio using "Project Owner" user with username containing "powner" and confirm that you see the consumer project and you can open it  | 
| extract-producer-info | Extracts id and role of the project producer | Provisions following SSM Parameters: <br> 1. /{app}/{env}/sagemaker/producer/id <br> 2. /{app}/{env}/sagemaker/producer/role <br> 3. /{app}/{env}/sagemaker/producer/role-name   | 
| extract-consumer-info | Extracts id and role of the project consumer | Provisions following SSM Parameters: <br> 1. /{app}/{env}/sagemaker/consumer/id <br> 2. /{app}/{env}/sagemaker/consumer/role <br> 3. /{app}/{env}/sagemaker/consumer/role-name   | 
---

## 5. **Glue Iceberg Jar File**

This module downloads and deploys the glue runtime jar file that is needed for glue jobs to interact with Iceberg tables. 

#### To deploy the module:

```
make deploy-glue-jars
```

| Target                 | Result          | Verification  | 
|-------------------------|------------------|----------|
| deploy-glue-jars   | Deploy Glue jar file | Verify that the iceberg jar file "s3-tables-catalog-for-iceberg-runtime-0.1.5.jar" is uploaded to S3 bucket "{app}-{env}-glue-jars-primary"  |   
---

## 6. **Lake Formation**

This module deploys lake formation configuration to create Glue catalog for s3tables and registers s3table bucket location with lake formation using lake formation service role. 

#### To deploy the module:

```
make create-glue-s3tables-catalog
make register-s3table-catalog-with-lake-formation
```

| Target                                      | Result                                | Verification                 | 
|----------------------------------------------|----------------------------------------|-------------------------|
| create-glue-s3tables-catalog                 | Create Glue catalog for S3tables                    | Verify that the following Glue catalog is created in Lakeformation by opening "Data Catalog -> Catlogs": <br> 1. s3tablescatalog                |    
| register-s3table-catalog-with-lake-formation | Registers S3 table location with lake formation | Verify that the s3table location is registered with Lakeformation by opening "Administration->Data lake locations" and finding an entry for the following data lake location: <br> 1. s3://tables:{region}:{account}:bucket/*  |      

## 7. **Athena**

This module deploys an athena workgroup. 

#### To deploy the module:

```
make deploy-athena
```

| Target                       | Result                                   | Verification    | 
|-------------------------------|-------------------------------------------|------------|
| deploy-athena                 | Create Athena workgroup                      | Verify following Athena workgroup is created <br> 1. {app}-{env}-workgroup         | 
---

## 8. **Data Lakes**

The solution allows the user to deploy 3 data lakes, 1) billing data lake 2) inventory data lake and 3) splunk data lake. Although we recommend that the user deploys all the 3 data lakes, the user does not need to deploy all the 3 data lakes. If the user wishes to deploy only one data lake to explore the functionalities of Nexus solution, then we recommend deploying the billing data lake at the minimum. 

## 9. **Billing Data Lake - Static**

Billing Data Lake is divided into 3 modules. 1) Static - Glue Jobs for Tables with Static Schema 2) Dynamic - Glue Jobs for Tables with Dynamic Schema and 3) CUR - Setting up CUR reports after 24 hours of enabling cost explorer in Billing and Cost Management. 

This module sets up the Glue Jobs for Tables with Static Schema. 

#### To deploy the module:

```
make deploy-billing
make grant-default-database-permissions 
make drop-default-database
make start-billing-hive-job (wait for glue job to complete)
make start-billing-iceberg-static-job (wait for glue job to complete)
make start-billing-s3table-create-job (wait for glue job to complete)
make start-billing-s3table-job (wait for glue job to complete)
make grant-lake-formation-billing-s3-table-catalog
make start-billing-hive-data-quality-ruleset
make start-billing-iceberg-data-quality-ruleset
```

| Target                                          | Result                                                        | Verification                                     | 
|--------------------------------------------------|----------------------------------------------------------------|---------------------------------------------|
| deploy-billing                                   | Deploy billing infrastructure                                          | Following S3 buckets are created: <br> 1. {app}-{env}-billing-data-primary <br> 2. {app}-{env}-billing-data-primary-log  <br> 3. {app}-{env}-billing-data-secondary <br> 4. {app}-{env}-billing-data-secondary-log <br> 5. {app}-{env}-billing-hive-primary <br> 6. {app}-{env}-billing-hive-primary-log  <br> 7. {app}-{env}-billing-hive-secondary <br> 8. {app}-{env}-billing-hive-data-secondary-log <br> 9. {app}-{env}-billing-iceberg-primary <br> 10. {app}-{env}-billing-iceberg-primary-log  <br> 11. {app}-{env}-billing-iceberg-secondary <br> 12. {app}-{env}-billing-iceberg-data-secondary-log. <br><br> Following S3 table bucket is created: <br> 1. {app}-{env}-billing <br> <br> Following Glue database is created: <br> 1. {app}_{env}_billing <br><br> Following Glue tables are created: <br> 1. {app}_{env}_billing_hive <br> 2. {app}_{env}_billing_iceberg_static <br><br> Following Glue jobs are created: <br> 1. {app}-{env}-billing-hive <br> 2. {app}-{env}-billing-iceberg-static <br> 3. {app}-{env}-billing-s3table-create <br> 4. {app}-{env}-billing-s3table-delete <br> 5. {app}-{env}-billing-s3table                          |    
| grant-default-database-permissions | Grant deployment role permission to drop "default" database | Verify that the deployment role is granted permission to drop "default" database | 
| drop-default-database | Drop "default" Glue database | Verify that the "default" Glue database is dropped |
| start-billing-hive-job                           | Run the {app}-{env}-billing-hive glue job                                          | Verify that the glue job starts. wait for the glue job to complete |
| start-billing-iceberg-static-job                 | Run the {app}-{env}-billing-iceberg-static glue job                                | Verify that the glue job starts. wait for the glue job to complete |   
| start-billing-s3table-create-job                 | Run the {app}-{env}-billing-s3table-create job                      | Verify that the glue job starts. wait for the glue job to complete                    |    
| start-billing-s3table-job                        | Run the  {app}-{env}-billing-s3table job                     | Verify that the glue job starts. wait for the glue job to complete            |    
| grant-lake-formation-billing-s3-table-catalog    | Grant Lake Formation permissions to inventory S3 table catalog | Verify that the permission is added Lakeformation                    |    
| start-billing-hive-data-quality-ruleset          | Execute billing_hive_ruleset associated with {app}_{env}_billing_hive Glue table                     | Verify that billing_hive_ruleset is executed                  |    
| start-billing-iceberg-data-quality-ruleset       | Execute billing_iceberg_ruleset associated with {app}_{env}_billing_iceberg_statics Glue table             | Verify that billing_iceberg_ruleset is executed                    |    

## 10. **Billing Data Lake - Dynamic**

Billing Data Lake is divided into 3 modules. 1) Static - Glue Jobs for Tables with Static Schema 2) Dynamic - Glue Jobs for Tables with Dynamic Schema and 3) CUR - Setting up CUR reports after 24 hours of enabling cost explorer report. 

This module sets up the Glue Jobs for Tables with Dynamic Schema. 

#### To deploy the module:

```
make upload-billing-dynamic-report-1 (wait for billing-workflow to start and complete)
make upload-billing-dynamic-report-2 (wait for billing-workflow to start and complete)
make grant-lake-formation-billing-iceberg-dynamic
```

| Target      |                            Result                               | Verification                  | 
|----------------------------------------------------------------------------------------------|----| ----|
| upload-billing-dynamic-report-1                   | Uploads the first cost and usage report to an S3 bucket for triggering a dynamic Glue workflow for billing data processing {app}-{env}-billing-workflow | Verify that the following Glue workflow is executed: <br> 1. {app}-{env}-billing-workflow <br> <br> After the glue workflow completes, confirm creation of the following Glue table: <br> 1. {app}_{env}_billing_iceberg_dynamic                 |    
| upload-billing-dynamic-report-2                   | Uploads the second cost and usage report to an S3 bucket for triggering a dynamic Glue workflow for billing data processing {app}_{env}-billing-workflow | Verify that the following Glue workflow is executed: <br> 1. {app}-{env}-billing-workflow                 | 
| grant-lake-formation-billing-iceberg-dynamic      | Grants lake formation permissions to an admin role for accessing and managing the Iceberg table {app}_{env}_billing_iceberg_dynamic | Verify that the Lakeformation permisison is granted |
---    

## 11. **Billing Data Lake - CUR**

> [!CAUTION]
> Please execute "Billing Set UP" as outlined below and then wait for at least 24 hours before deploying this module, due to the nature of Billing and Cost Management. In the meantime, you can proceed to the [the next section](#12-inventory-data-lake---static).

Billing Data Lake is divided into 3 modules. 1) Static - Glue Jobs for Tables with Static Schema 2) Dynamic - Glue Jobs for Tables with Dynamic Schema and 3) CUR - Setting up CUR reports after 24 hours of enabling cost explorer report. 

This module sets up the Cost and Usage Report. 

**Billing Set Up**: You will need to enable Cost Explorer in Billing and Cost Management before you can configure it to generate daily CUR reports in a S3 bucket. If you have not done this for your account already, please open "Billing and Cost Management" and click on "Cost Explorer" under "Cost and Usage Analysis". When you visit this page for the first time it will show a welcome message "Welcome to AWS Cost Management. Since this is your first visit, it will take some time to prepare your cost and usage data. Please check back in 24 hours."

#### To deploy the module:

```
make activate-cost-allocation-tags
make deploy-billing-cur
```

| Target                       | Result                                                                                                                           | Verification     |
|-------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|------------------|
| activate-cost-allocation-tags | Activate cost allocation tag in AWS Cost Explorer                                                                                 | Verify that the cost allocation tags are activated in Billing and Cost Management   |   
| deploy-billing-cur            | Deploy an AWS Cost and Usage Report (CUR) configuration to generate Cost and Usage Reports (CUR) daily  | Verify that Cost and Usage Report (CUR) is created in Billing and Cost Management   |


## 12. **Inventory Data Lake - Static**

Inventory Data Lake is divided into 2 modules. 1) Static - Glue Jobs for Tables with Static Schema 2) Dynamic - Glue Jobs for Tables with Dynamic Schema 

This module sets up the Glue Jobs for Tables with Static Schema. 

#### To deploy the module:

```
make deploy-inventory
make grant-default-database-permissions 
make drop-default-database
make start-inventory-hive-job (wait for glue job to complete)
make start-inventory-iceberg-static-job (wait for glue job to complete)
make start-inventory-s3table-create-job (wait for glue job to complete)
make start-inventory-s3table-job (wait for glue job to complete)
make grant-lake-formation-inventory-s3-table-catalog 
make start-inventory-hive-data-quality-ruleset 
make start-inventory-iceberg-data-quality-ruleset
```

| Target                                          | Result                                                        | Verification                                     | 
|--------------------------------------------------|----------------------------------------------------------------|---------------------------------------------|
| deploy-inventory                                   | Deploy inventory infrastructure                                          | Following S3 buckets are creatd: <br> 1. {app}-{env}-inventory-data-primary <br> 2. {app}-{env}-inventory-data-primary-log  <br> 3. {app}-{env}-inventory-data-secondary <br> 4. {app}-{env}-inventory-data-secondary-log <br> 5. {app}-{env}-inventory-hive-primary <br> 6. {app}-{env}-inventory-hive-primary-log  <br> 7. {app}-{env}-inventory-hive-secondary <br> 8. {app}-{env}-inventory-hive-data-secondary-log <br> 9. {app}-{env}-inventory-iceberg-primary <br> 10. {app}-{env}-inventory-iceberg-primary-log  <br> 11. {app}-{env}-inventory-iceberg-secondary <br> 12. {app}-{env}-inventory-iceberg-data-secondary-log. <br><br> Following S3 table bucket is created: <br> 1. {app}-{env}-inventory <br> <br> Following Glue database is created: <br> 1. {app}_{env}_inventory <br><br> Following Glue tables are created <br> 1. {app}_{env}_inventory_hive <br> 2. {app}_{env}_inventory_iceberg_static <br><br> Following Glue jobs are created: <br> 1. {app}-{env}-inventory-hive <br> 2. {app}-{env}-inventory-iceberg-static <br> 3. {app}-{env}-inventory-s3table-create <br> 4. {app}-{env}-inventory-s3table-delete <br> 5. {app}-{env}-inventory-s3table                          |    
| grant-default-database-permissions | Grant deployment role permission to drop "default" Glue database | Verify that the deployment role is granted permission to drop "default" database | 
| drop-default-database | Drops "default" Glue database | Verify that the "default" Glue database is dropped | 
| start-inventory-hive-job                           | Run the {app}-{env}-inventory-hive glue job                                          | Verify that the glue job starts. wait for the glue job to complete |
| start-inventory-iceberg-static-job                 | Run the {app}-{env}-inventory-iceberg-static glue job                                | Verify that the glue job starts. wait for the glue job to complete |   
| start-inventory-s3table-create-job                 | Run the {app}-{env}-inventory-s3table-create job                      | Verify that the glue job starts. wait for the glue job to complete                    |    
| start-inventory-s3table-job                        | Run the  {app}-{env}-inventory-s3table job                     | Verify that the glue job starts. wait for the glue job to complete            |    
| grant-lake-formation-inventory-s3-table-catalog    | Grant Lake Formation permissions to inventory S3 table catalog | Verify that the permission is added Lakeformation                    |    
| start-inventory-hive-data-quality-ruleset          | Execute inventory_hive_ruleset associated with {app}_{env}_inventory_hive Glue table                     | Verify that inventory_hive_ruleset is executed                  |    
| start-inventory-iceberg-data-quality-ruleset       | Execute inventory_iceberg_ruleset associated with {app}_{env}_inventory_iceberg_statics Glue table             | Verify that inventory_iceberg_ruleset is executed                    |    

## 13. **Inventory Data Lake - Dynamic**

Inventory Data Lake is divided into 2 modules. 1) Static - Glue Jobs for Tables with Static Schema 2) Dynamic - Glue Jobs for Tables with Dynamic Schema and 

This module sets up the Glue Jobs for Tables with Dynamic Schema. 

#### To deploy the module:

```
make upload-inventory-dynamic-report-1 (wait for inventory-workflow to start and complete)
make upload-inventory-dynamic-report-2 (wait for inventory-workflow to start and complete)
make grant-lake-formation-inventory-iceberg-dynamic
```

| Target      |                            Result                               | Verification                  | 
|----------------------------------------------------------------------------------------------|----| ----|
| upload-inventory-dynamic-report-1                   | Uploads the first inventory report to an S3 bucket for triggering a dynamic Glue workflow for inventory data processing {app}_{env}-inventory-workflow | Verify that the following Glue workflow is executed: <br> 1. {app}_{env}-inventory-workflow <br> <br> After the glue workflow completes, confirm creation of the following Glue table: <br> 1. {app}_{env}_inventory_iceberg_dynamic                 |    
| upload-inventory-dynamic-report-2                   | Uploads the second inventory report to an S3 bucket for triggering a dynamic Glue workflow for inventory data processing {app}_{env}-inventory-workflow | Verify that the following Glue workflow is executed: <br> 1. {app}_{env}-inventory-workflow                 | 
| grant-lake-formation-inventory-iceberg-dynamic      | Grants lake formation permissions to an admin role for accessing and managing the Iceberg table {app}_{env}_inventory_iceberg_dynamic | Verify that the Lakeformation permisison is granted |
---  

## 14. **Splunk Datalake**

This module deploys splunk datalake.

#### To deploy the module:

```
make deploy-network (wait for glue job to complete)
make deploy-splunk (wait for EC2 instance's Status check to show '3/3 checks passed' before proceeding, recommended to wait at least 5 minutes before proceeding)
make grant-default-database-permissions 
make drop-default-database
make start-splunk-iceberg-static-job (wait for glue job to complete)
make start-splunk-s3table-create-job (wait for glue job to complete)
make start-splunk-s3table-job 
make grant-lake-formation-splunk-s3-table-catalog 
```

| Target                                      | Result                                                     | Verification                                     | 
|----------------------------------------------|-------------------------------------------------------------|---------------------------------------------|
| deploy-network                               | Deploy VPC network for Splunk application                             | Verify that the following VPC is created: <br> 1. {app}_{env}-vpc                                    |    
| deploy-splunk                                | Deploy splunk application to an EC2 instance and configure it                                              | Verify that the following EC2 instance is created. <br> 1. {app}_{env}-splunk-instance <br> 2. Give 10 minutes for Splunk instance to be operational on EC2, and then execute the remaining make targets <br><br> Following S3 buckets are creatd: <br> 1. {app}-{env}-splunk-iceberg-primary <br> 2. {app}-{env}-splunk-iceberg-primary-log  <br> 3. {app}-{env}-splunk-iceberg-secondary <br> 4. {app}-{env}-splunk-iceberg-data-secondary-log. <br><br> Following S3 table bucket is created: <br> 1. {app}-{env}-splunk <br> <br> Verify that following Glue database is created: <br> 1. {app}_{env}_splunk <br><br> Following Glue tables are created: <br> 1. {app}_{env}_splunk_iceberg <br><br> Following Glue jobs are created: <br> 1. {app}-{env}-splunk-iceberg-static <br> 2. {app}-{env}-splunk-s3table-create <br> 3. {app}-{env}-splunk-s3table-delete <br> 4. {app}_{env}-splunk-s3table                                  |    
| grant-default-database-permissions | Grant deployment role permission to drop "default" database | Verify that the deployment role is granted permission to drop "default" database | 
| drop-default-database | Drop "default" Glue database | Verify that the "default" Glue database is dropped | 
| start-splunk-iceberg-static-job              | Run {app}-{env}-splunk-iceberg-static Glue job                                       | Verify that the glue job starts. wait for the glue job to complete |    
| start-splunk-s3table-create-job              | Run {app}-{env}-splunk-s3table-create Glue job                     | Verify that the glue job starts. wait for the glue job to complete                     |    
| start-splunk-s3table-job                     | Run {app}-{env}-splunk-s3table-create Glue job                     | Verify that the glue job starts. wait for the glue job to complete             |    
| grant-lake-formation-splunk-s3-table-catalog | Grant Lake Formation permissions to Splunk S3 table catalog  |
---   

## 15. **Sagemaker Project Configuration**

This module configures the Sagemaker Producer and Consumer Projects to load the Data Lakes into Lakehouse by granting project roles lake house permissions to the data lakes. 

#### To deploy the module:

```
make deploy-project-config
make billing-grant-producer-s3tables-catalog-permissions
make inventory-grant-producer-s3tables-catalog-permissions
make splunk-grant-producer-s3tables-catalog-permissions
```

| Target                                               | Result                                                                                                                  | Verification                  | 
|-------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|--------------------------|
| deploy-project-config                                 | Deploy Project Config                                                                                                    | Grants Lake Formation permissions to the producer project role and consumer project role to access the 3 data lakes                 | Verify that the project roles are granted lake formation permissions |   
| billing-grant-producer-s3tables-catalog-permissions   | Grants Lake Formation access permissions to a project producer role for querying billing data through S3 table catalog   | Verify that the project role is granted lake formation permissions  |     
| inventory-grant-producer-s3tables-catalog-permissions | Grants Lake Formation access permissions to a project producer role for querying inventory data through S3 table catalog | Verify that the project role is granted lake formation permissions  |    
| splunk-grant-producer-s3tables-catalog-permissions    | Grants Lake Formation access permissions to a project producer role for querying splunk data through S3 table catalog    | Verify that the project role is granted lake formation permissions  |    
---   

## 16. **Datazone Domain and Projects**

This module deploys datazone domain and datazone project. 

#### To deploy the module:

```
make deploy-datazone-domain
make deploy-datazone-project-prereq (wait for 5 minutes for the environment to be created and activated)
make deploy-datazone-producer-project
make deploy-datazone-consumer-project
make deploy-datazone-custom-project
```

| Target                  | Result                 | Verify                            | 
|--------------------------|-------------------------|------------------------------------|
| deploy-datazone-domain   | Deploy Datazone Domain  | Verify that a Datazone domain **Exchange** is created |    
| deploy-datazone-project-prereq  | Deploy Datazone Project Prerequisites | Verify that Datazone project prerequisites are created **producer_project**, **consumer_project** and **custom_project** are created in the Datazone domain **Exchange**  | deploy-datazone-procuder-project  | Deploy Datazone Producer Project | Verify that Datazone **Producer** project is created in the Datazone domain **Exchange**  | deploy-datazone-consumer-project  | Deploy Datazone Consumer Project | Verify that Datazone **Consumer** project is created in the Datazone domain **Exchange**  | deploy-datazone-custom-project  | Deploy Datazone Consumer Project | Verify that Datazone **Custom** project is created in the Datazone domain **Exchange**  | 
---

## 17. **Quicksight Subscription**

This module deploys subscription for quicksight.

#### To deploy the module:

```
make deploy-quicksight-subscription 
```

| Target                        | Result                        | Verify                                                         |
|--------------------------------|--------------------------------|----------------------------------------------------------------------|
| deploy-quicksight-subscription | Deploy QuickSight subscription | Log into the console and directly see the main QuickSight homepage and confirm subscription is created |   
---

#### Important Limitation
Currently (as of March 2025), there is a known limitation when creating a QuickSight subscription via Terraform or AWS API:
- You cannot programmatically assign IAM roles or configure data sources during the initial subscription creation
- This requires a two-step deployment process - if you proceed to create QuickSight subscription through Terraform/API
- Refer to the documentation [here](https://docs.aws.amazon.com/quicksight/latest/APIReference/API_CreateAccountSubscription.html)



## 18. **Quicksight Visualization**

This module deploys datasource, datasets and dashboard visualization for quicksight. 

#### Before deploying this step: 
- Once the subscription is created, navigate to: QuickSight → Manage QuickSight → Security & Permissions
- Locate "IAM Role In Use" section and click "Manage"
- Choose "Use an existing role"
- Select {app}-{env}-quicksight-service-role
- Note: The quicksight-service-role is a custom IAM role configured with least-privilege access to:
    - Amazon Athena
    - AWS Glue Catalog
    - Amazon S3
    - AWS Lake Formation
- After IAM configuration is completed, we can create datasource and dataset using `make deploy-quicksight`

#### Additional Information About IAM Role Configuration

The IAM Role selection process is a one-time setup requirement for each AWS Root Account where the subscription exists. If you delete and later recreate the subscription in the same AWS Root Account, you will not need to reconfigure the IAM Role because:

1. The IAM configuration is cached by the service
2. The system will automatically use the previously configured IAM Role settings

**Note:** This automatic role reuse only applies when recreating subscriptions within the same AWS Root Account.

#### To deploy the module:

```
make deploy-quicksight-dataset 
```

| Target                        | Result                                | Verfication                                                                                  |
|--------------------------------|----------------------------------------|-----------------------------------------------------------------------------------------------|
| deploy-quicksight-dataset | Deploy QuickSight dataset and reports | Verify that you see a {app}_{env}_Billing_Dashboard populated with data  |
---

## 19. **Custom Data Lineage**

This module helps users create custom assets and publish custom lineage to Sagemaker Catalog. 

Grant project owner permission to create custom asset type:

1. Navigate to the Amazon SageMaker in the AWS Console and select "Corporate" domain
2. Login to the Sagemaker Unified Studio using the domain owner role with "downer" in the name (`ann-chouvey-downer@example.com` in this tutorial)
3. Click on "Govern->Domain units" to open "Domain Units" page
4. Click "Corporate" to open the root domain unit
5. Scroll down to click on "Metadata form creation policy"
6. Click on "ADD POLICY GRANT" button
7. Select "Corporate" as the project
8. Select "Producer" project from the projects dropdown
9. Select both "Owner" and "Contributor"
10. Click on "ADD POLICY GRANT" button
11. Log out of the Sagemaker Unified Studio

Create Sagemaker notebook to create custom assets and custom lineage:

1. Login to the Sagemaker Unified Studio using the project owner role with "powner" in the name (`lois-lanikini-powner@example.com` in this tutorial)
2. Select "Browse all project" button and open "Producer" Project
3. Select "Build->JupyterLab" from the top bar
4. Click "Start space" button if it has not started
5. Click on "Python 3" to create a Jupyter Notebook using Python3
6. Click on "Save" icon to give the notebook a name, enter "Lineage.ipynb" and click on "Rename" button
7. Copy the content of the file "/iac/roots/sagemaker/lineage/lineage.py" into the cell of Jupyter Notebook
8. Update line 371 with the app name you selected and line 372 with the environment name you selected
9. Execute the notebook

Verify custom assets and custom lineage:

1. Select "Producer->Data" in top middle drop down
2. Click on "Project catalog->Assets"
3. It should show you 2 custom assets: "Trade" and "Order"
4. Click on "Trade" asset
5. Click on "Lineage" tab on top
6. Click on "<<" buttton on left of "Job run" to expand it
7. Click on "3 columns" drop down in "Trade" asset to expand the columns
8. You should see column level lineage between "Order" and "Trade" assets 