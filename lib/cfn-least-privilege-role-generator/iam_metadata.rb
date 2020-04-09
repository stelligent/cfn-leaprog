require 'kramdown'
require 'open-uri'
require_relative 'aws_services'

class IamMetadata
  # this is totally subject to breaking horribly once AWS makes one false move
  # use a local copy if there is an exception
  # nil coming back if service not found
  def resource_level_permissions?(service_prefix)
    begin
      iam_resource_db_md = URI.open('https://raw.githubusercontent.com/awsdocs/iam-user-guide/master/doc_source/reference_aws-services-that-work-with-iam.md').read
      root = Kramdown::Document.new(iam_resource_db_md).root
      iam_resource_level_support_hash = {}
      tables(root).each do |table|
        tbody = table.children[1]
        for row_number in 0..tbody.children.size
          next if tbody.children[row_number].nil?

          row = tbody.children[row_number].children
          aws_service_name = service_name_from_table_row(row)
          supported = resource_level_permissions_from_table_row(row)

          iam_resource_level_support_hash[aws_service_name] = supported
        end
      end
    rescue Exception => e
      iam_resource_level_support_hash = default_iam_resource_level_support_hash
    end
    verbose_service_name = AwsServices.new.prefix_to_verbose_service_name[service_prefix]
    return nil if verbose_service_name.nil?
    iam_resource_level_support_hash[verbose_service_name]
  end

  private

  def resource_level_permissions_from_table_row(row)
    second_column = row[2]
    second_column_text = second_column.children[0].value

    # no text, could be a link like AWS Batch
    if second_column_text.nil?
      second_column_text = second_column.children[0].children[0].value
    end

    second_column_text.start_with?('Yes')
  end

  def service_name_from_table_row(row)
    service_name = row[0].children[0].value
    # no text, could be a link like AWS Batch
    if service_name.nil?
      service_name = row[0].children[0].children[0].value
    end
    service_name
  end

  def tables(root)
    root.children.select { |element| element.type == :table }
  end

  def default_iam_resource_level_support_hash
    {"AWS Batch"=>true, "Amazon Elastic Compute Cloud (Amazon EC2)"=>true, "Amazon EC2 Auto Scaling"=>true, "Amazon EC2 Image Builder"=>true, "AWS Elastic Beanstalk"=>true, "Amazon Elastic Container Registry (Amazon ECR)"=>true, "Amazon Elastic Container Service (Amazon ECS)"=>true, "Amazon Elastic Kubernetes Service (Amazon EKS)"=>true, "Amazon Elastic Inference"=>true, "Elastic Load Balancing"=>true, "AWS Lambda"=>true, "Amazon Lightsail"=>true, "AWS Outposts"=>true, "AWS Serverless Application Repository"=>true, "AWS Backup"=>true, "AWS Backup Storage"=>true, "Amazon Elastic Block Store (Amazon EBS)"=>true, "Amazon Elastic File System (Amazon EFS)"=>true, "Amazon FSx"=>true, "Amazon S3 Glacier"=>true, "AWS Import/Export"=>false, "AWS Migration Hub"=>true, "Amazon Simple Storage Service (Amazon S3)"=>true, "AWS Snowball"=>false, "AWS Snowball Edge"=>false, "AWS Storage Gateway"=>true, "Amazon DynamoDB"=>true, "Amazon ElastiCache"=>false, "AWS Managed Apache Cassandra Service (MCS)"=>true, "Amazon Quantum Ledger Database (Amazon QLDB)"=>true, "Amazon Redshift"=>true, "Amazon Relational Database Service (Amazon RDS)"=>true, "Amazon RDS Data API"=>false, "Amazon SimpleDB"=>true, "AWS Cloud9"=>true, "CodeBuild"=>true, "CodeCommit"=>true, "AWS CodeDeploy"=>true, "CodePipeline"=>true, "AWS CodeStar"=>true, "AWS CodeStar Notifications"=>true, "AWS X-Ray"=>true, "AWS Certificate Manager Private Certificate Authority (ACM)"=>true, "AWS Artifact"=>true, "AWS Certificate Manager (ACM)"=>true, "AWS CloudHSM"=>true, "AWS CloudHSM Classic"=>false, "Amazon Cognito"=>true, "Amazon Detective"=>true, "AWS Directory Service"=>true, "AWS Firewall Manager"=>true, "Amazon GuardDuty"=>true, "AWS Identity and Access Management (IAM)"=>true, "IAM Access Analyzer"=>true, "Amazon Inspector"=>false, "AWS Key Management Service (AWS KMS)"=>true, "Amazon Macie "=>false, "AWS Resource Access Manager (AWS RAM)"=>true, "AWS Secrets Manager"=>true, "AWS Security Hub"=>true, "AWS Single Sign-On (AWS SSO)"=>false, "AWS SSO Directory"=>false, "AWS Security Token Service (AWS STS)"=>true, "AWS Shield Advanced"=>true, "AWS WAF"=>true, "AWS WAFV2"=>true, "Amazon CodeGuru Profiler"=>true, "Amazon CodeGuru Reviewer"=>true, "Amazon Comprehend"=>true, "AWS DeepRacer"=>false, "Forecast"=>true, "Amazon Fraud Detector"=>false, "Ground Truth Labeling"=>false, "Amazon Kendra"=>true, "Amazon Lex"=>true, "Amazon Machine Learning"=>true, "Amazon Personalize"=>true, "Amazon Polly"=>true, "Amazon Rekognition"=>true, "Amazon SageMaker"=>true, "Amazon Textract"=>true, "Amazon Transcribe"=>false, "Amazon Translate"=>false, "Application Auto Scaling"=>false, "AWS AppConfig"=>true, "AWS Auto Scaling"=>false, "AWS Chatbot "=>true, "AWS CloudFormation"=>true, "AWS CloudTrail"=>true, "Amazon CloudWatch"=>true, "Amazon CloudWatch Events"=>true, "Amazon CloudWatch Logs "=>true, "Amazon CloudWatch Synthetics"=>true, "AWS Compute Optimizer"=>false, "AWS Config"=>true, "Amazon Data Lifecycle Manager"=>true, "AWS Health"=>true, "AWS OpsWorks"=>true, "AWS OpsWorks for Chef Automate"=>true, "AWS Organizations"=>true, "AWS Resource Groups"=>true, "Resource Groups Tagging API"=>false, "AWS Service Catalog"=>false, "AWS Systems Manager"=>true, "AWS Trusted Advisor"=>true, "AWS Well-Architected Tool"=>true, "AWS Database Migration Service"=>true, "AWS Application Discovery Service"=>false, "AWS Server Migration Service"=>false, "AWS Amplify"=>true, "AWS Device Farm"=>true, "Amazon API Gateway"=>true, "AWS App Mesh"=>true, "Amazon CloudFront"=>true, "AWS Cloud Map"=>true, "AWS Direct Connect"=>true, "AWS Global Accelerator"=>true, "Network Manager"=>true, "Amazon Route 53"=>true, "Amazon Route 53 Resolver"=>true, "Amazon Virtual Private Cloud (Amazon VPC)"=>true, "Amazon Elastic Transcoder"=>true, "AWS Elemental MediaConnect"=>true, "AWS Elemental MediaConvert"=>true, "AWS Elemental MediaLive"=>true, "AWS Elemental MediaPackage"=>true, "AWS Elemental MediaStore"=>true, "AWS Elemental MediaTailor"=>true, "Kinesis Video Streams"=>true, "Amazon Athena"=>true, "Amazon CloudSearch"=>true, "AWS Data Exchange"=>true, "AWS Data Pipeline"=>false, "Amazon Elasticsearch Service"=>true, "Amazon EMR"=>false, "AWS Glue"=>true, "Amazon Kinesis Data Analytics"=>true, "Amazon Kinesis Data Firehose"=>true, "Amazon Kinesis Data Streams"=>true, "AWS Lake Formation"=>false, "Amazon Managed Streaming for Apache Kafka (MSK)"=>true, "Amazon QuickSight"=>true, "Amazon EventBridge"=>true, "Amazon EventBridge Schemas"=>true, "Amazon MQ"=>true, "Amazon Simple Notification Service (Amazon SNS)"=>true, "Amazon Simple Queue Service (Amazon SQS)"=>true, "AWS Step Functions"=>true, "Amazon Simple Workflow Service (Amazon SWF)"=>true, "Alexa for Business"=>true, "Amazon Chime"=>false, "Amazon WorkMail"=>false, "AWS Ground Station"=>true, "AWS IoT Greengrass"=>true, "AWS IoT"=>true, "AWS IoT Analytics"=>true, "AWS IoT Device Tester"=>false, "AWS IoT Events"=>true, "AWS IoT Things Graph"=>false, "AWS IoT SiteWise"=>true, "FreeRTOS"=>true, "RoboMaker"=>true, "Amazon Managed Blockchain"=>true, "Amazon GameLift"=>true, "Amazon Sumerian"=>true, "Amazon Connect"=>true, "Amazon Pinpoint"=>true, "Amazon Simple Email Service (Amazon SES)"=>true, "Amazon AppStream"=>false, "Amazon AppStream 2.0"=>true, "Amazon WAM"=>false, "Amazon WorkDocs"=>false, "Amazon WorkLink"=>true, "Amazon WorkSpaces"=>true, "AWS Billing and Cost Management"=>false, "AWS Marketplace"=>false, "AWS Marketplace Catalog"=>true, "AWS Private Marketplace"=>false, "AWS Support"=>false}
  end
end