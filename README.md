## Background
This tool is an experimental approach to generating least privileged IAM roles 
for CloudFormation and Service Catalog Launch Constraints.

The sourcebase contains two approaches.  

This doc describes how to execute the CloudTrail event filtering approach.

The other approach involves scraping CloudFormation stack events.  It is NOT recommended
but is kept here for historical reference.

## Setup the Infrastructure

Make sure your environment has default AWS credentials that can setup
CloudTrail, CloudWatch and DynamoDB.

Make sure you have a recent Ruby installed.  2.6 was used for development.

```
bundle install
rake ct:infra
```

### Converge a CloudFormation Template

First select a CloudFormation template that you want to generate the least privileged 
policy/role for.  The `spec/test_templates/DynamoDB_Table.template` is a simple one 
to start with.  

Edit the parameter values in `spec/test_templates/parameters/ddb.json` to your liking.

Then execute the rake task to converge the template:
```
rake ct:create_stack[spec/test_templates/DynamoDB_Table.template,spec/test_templates/parameters/ddb.json]
```

The rake task will emit an IAM role ARN to stdout.  Copy this text for the next step.

### Generate the Policy
Wait a number of minutes for CloudTrail to catch up - usually 5-15 minutes.

```
rake ct:policy[arn:aws:iam::11111111111:role/cfn-least-privilege-role-generator-1586791962]
```

### Teardown
Optionally tear down all the CloudTrail and CloudWatch Logs and Lambda infrastructure
to save on costs when not in use.  It only takes a matter of a minute to spin up again....

```
rake ct:teardown_infra
```
