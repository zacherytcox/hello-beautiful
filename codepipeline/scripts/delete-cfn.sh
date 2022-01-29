#!/bin/bash

stack_name=$1

aws cloudformation delete-stack --stack-name $stack_name

if [ "$?" == '0' ]
    then
        echo Stack Deleted Successfully
    else
        exit 1
fi 