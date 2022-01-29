#!/bin/bash

stack_name="$1"

bucket=$(aws cloudformation describe-stacks --stack $stack_name --query 'Stacks[0].Outputs[?OutputKey==`BucketOutput`].OutputValue' | jq -r '.[]')

code=$(curl --write-out '%{http_code}' --silent --output /dev/null "$bucket.s3-website-us-east-1.amazonaws.com"/)

if [ "$code" == '200' ]
    then
        echo "Homepage is active ($code)"
    else
        echo "Homepage errors ("$code")"
        exit 1
fi 