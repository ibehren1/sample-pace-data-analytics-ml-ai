# **DAIVI** : *A Reference Solution to accelerate development of Data, Analytics, AI and Visualization applications on AWS*

## Table of Contents
- [About DAIVI](#about-daivi)
    - [Solution Vision](#solution-vision)
    - [Solution Architecture](#solution-architecture)
    - [Solution Components](#solution-components)
- [Management Data Lake for Cost Analytics](#management-data-lake-for-cost-analytics)
    - [High Level Architecture](#high-level-architecture)
- [Deploying DAIVI](./docs/main/solutions-deployment.md)
- [Exploring DAIVI](./docs/demo/exploring-daivi.md)
- [Security Recommendatioms](./docs/main/security-recommendations.md)
- [Contributors](#contributors)


## About DAIVI on AWS

DAIVI is a reference solution with IAC modules to accelerate development of Data, Analytics, AI and Visualization applications on AWS using the next generation "**Amazon SageMaker**" platform. The goal of the DAIVI solution is to provide engineers with sample infrastructure-as-code modules and application modules to build their enterprise data platform on AWS. The solution is being developed working backward from customer priorities. 

The solution currently supports the first 6 modules marked in green in the solution roadmap below, that include 

1. Identity Center modules for Organization Level and Account Level Identity Centers with Users, Groups, Permissions and IAM Mapping 
2. Data Lake modules to create Hive Tables and Iceberg Tables, both on standard S3 bucket and S3 Table bucket 
3. Sagemake modules to provision domains and projects, add members to the projects, configure lakehouse and add compute 
4. Sagemaker Catalog modules to support standard assets, custom assets, data lineage, both standard and custom, data quality and data mesh 
5. DataZone modules to support standard assets, custom blueprints, data lineage, both standard and custom, data quality and data mesh 
6. Data pipeline module for Glue batch pipeline, Data exploration module for Athena and Data visualization module for Quicksight. 

### Solution Vision

![Vision](./docs/images/daivi_vision.png)

### Solution Architecture

![Vision](./docs/images/daivi_solution.png)

### Solution Components

#### Data Lakes

The solution supports modules to provision 1) Hive data lakes on standard S3 buckets 2) Iceberg data lakes on standard S3 buckets and 3) Iceberg data lakes on S3 table buckets. In addition,it covers how customers can implement 1) transaction data lakes 2) schema evolution and 3) time travel queries on Iceberg data lakes. 

#### Data Pipelines

The solution plans to support 1) batch data pipelines using Glue 2) streaming data pipeline using Glue and 3) streaming data pipeline using Flink. The initial release supports modules to provision batch data pipelines using Glue.  

#### IAM Identity Center

The solutions supports modules to provision IAM Identity Center instances, at organization-level or account-level, create users and groups and grant them required permissions.  

#### Sagemaker Unified Studio

The solutions supports modules to provision Sagemaker domains and Sagemaker projects, with integration with IAM Identity Center to support various Sagemaker domain/project roles. It provisions one domain and creates two projects, producer and consumer. 

#### Sagemaker Lakehouse

The solutions supports modules to configure Sagemaker projects to load data lakes into  Sagemaker Lakehouse. 

#### Sagemaker Data Processing

The solutions demonstrates how to implement data processing using Athena, Redshift and EMR. 

#### Sagemaker Catalog

The solutions supports modules to configure Sagemaker projects to create data sources and load assets from data lakes, view data quality and data lineage. It also supports modules to create custom assets and custom lineage.  

#### Sagemaker Data Mesh

The solutions demonstrates how to implement a data mesh solution between a producer and consumer projects with proper data governance enforced by the producer project. 

#### Sagemaker Quicksight

The solutions demonstrates how to create visualization using Quicksight leveraging data from data lakes. 

Note: Additional reading about DAIVI architecture and Design principles [here](./docs/main/design-principles.md).

## Management Data Lake for Cost Analytics

Working backward from the needs of a customer, the solution implements a sample management data lake for cost analytics to demonstrate how to create Hive and Iceberg data lakes on S3 buckets and S3 table buckets, and how to implement batch data pipelines using Glue. 

### High level architecture

![High Level Architecture](./docs/images/solution_architecture.png)

### Data Lakes

All three data pipelines below receive data from different data sources and store them in Hive and Iceberg data lakes using standard S3 buckets or S3 table bucket.

#### 1. AWS Cost and Usage Data Lake

The solution uses a Glue batch data pipeline to load AWS Cost and Usage report to Hive and Iceberg data lakes.

![Cost](./docs/images/main/cost_usecase.png)

#### 2. AWS S3 Inventory Data Lake

The solution uses a Glue batch data pipeline to load AWS S3 Inventory report to Hive and Iceberg data lakes.

![Cost](./docs/images/main/inventory_usecase.png)

#### 3. Splunk Data Lake

The solution uses a Glue batch data pipeline to load operational data from a Splunk instance into Iceberg data lakes.

![Cost](./docs/images/main/splunk_usecase.png)

## Next Steps

- [Deploying DAIVI](./docs/main/solutions-deployment.md)
- [Exploring DAIVI](./docs/demo/exploring-daivi.md)
- [Security Recommendatioms](./docs/main/security-recommendations.md)
- Additional Resources: 
  - [About Amazon SageMaker Unified Studio](./docs/amazon-sagemaker-unified-studio.md)
  - [About Amazon SageMaker Unified Studio Lakehouse](./docs/amazon-sagemaker-unified-studio-lakehouse.md)

## Contributors

- [Bikash Behera](https://www.linkedin.com/in/bikash-behera/)
- [Max Tybar](https://www.linkedin.com/in/maxtybar/)
- [Rams Sundaram](https://www.linkedin.com/in/ramasubramanian-sundaram-2616312/)
- [Yong Zhang](https://www.linkedin.com/in/zhangyong/)
- [Noah Coffin](https://www.linkedin.com/in/noah-coffin/)
- [Vivian Bui](https://www.linkedin.com/in/vivian-bui-413a561b6/)
- [Lionel Pulickal](https://www.linkedin.com/in/pjlionel/)
- [Marine Haddad](https://www.linkedin.com/in/marine-haddad-38a542b5/)
- [Kshitija Nandkishor Dound](https://www.linkedin.com/in/kshitijadound/)
- [Hardik Thakkar](https://www.linkedin.com/in/hardikvthakkar/)