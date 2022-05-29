#!/bin/bash

echo "$1 $2"
if [[ "$2" == '' ]]
    then
        script_domain="data* test*"
    else
        script_domain="$2"
fi

cd ./codepipeline/scripts/

stack_name="$1"
scripts=$(ls $script_domain)

for script in $scripts
    do
        sh $script $stack_name
        result=$?
        echo "results: >"$result
        if [[ "$result" != '0' ]]
            then
                echo "Issue(s) within script: $script"
                exit 1
        fi
done
cd ../..