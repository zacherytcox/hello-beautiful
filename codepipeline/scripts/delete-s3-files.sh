#!/bin/bash

stack_name=$1

buckets=$(aws cloudformation describe-stack-resources --stack "$stack_name" | jq -r '.StackResources' | jq -r '.[] | select(.ResourceType=="AWS::S3::Bucket") | .PhysicalResourceId')

for bucket in $buckets
    do
        aws s3 rb --force s3://$bucket/ 
done