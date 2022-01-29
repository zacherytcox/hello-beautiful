#!/bin/bash

if [[ "$2" == '' ]]
    then
        script_domain="data* test*"
    else
        script_domain="$2"
fi

stack_name="$1"

scripts=$(ls "$script_domain")
pwd
echo $scripts

for script in $scripts
    do
        sh $script $stack_name
done