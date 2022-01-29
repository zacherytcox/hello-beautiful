#!/bin/bash

stack_name=$1

status=$(aws cloudformation describe-stacks --stack $stack_name | jq -r '.Stacks | .[].StackStatus')

if [ "$status" == 'UPDATE_COMPLETE' ] || [ "$status" == 'CREATE_COMPLETE' ]
    then
        echo Stack Completed Successfully
    else
        exit 1
fi 