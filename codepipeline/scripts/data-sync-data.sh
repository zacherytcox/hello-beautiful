#!/bin/bash

stack_name=$1

this_bucket=$(aws cloudformation describe-stacks --stack $stack_name --query 'Stacks[0].Outputs[?OutputKey==`BucketOutput`].OutputValue' | jq -r '.[]')

aws s3 sync ./code s3://$this_bucket --exclude "*.DS_Store"