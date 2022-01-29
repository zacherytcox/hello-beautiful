#!/bin/bash

#Set parameters
current_path=$(pwd)
YAMLLOCATION="file://$current_path/codepipeline/pipeline.yaml"
YAMLLOCATIONAPP="file://$current_path/app/app.yaml"
YAMLPARAMSLOCATION="file://$current_path/codepipeline/params.json"
STACKNAME="Hello-Beautiful"
REGION="us-east-1"
PROFILE="default"
# LOCAL_STATE="./.test.state.txt"
SSH_KEY_NAME="$(whoami)-$STACKNAME"

#Set profile and region for AWS CLI
alias aws="$(which aws) --profile $PROFILE --region $REGION"

# prints colored text
print_style () {
    # params: text, color
    local text=$1
    local text_color_name=$2

    #Light Blue
    if [ "$text_color_name" == "info" ] ; then
        COLOR="96m";
    #Blue
    elif [ "$text_color_name" == "blue" ] ; then
        COLOR="94m";
    #Green
    elif [ "$text_color_name" == "success" ] ; then
        COLOR="92m";
    #Yellow
    elif [ "$text_color_name" == "warning" ] ; then
        COLOR="93m";
    #Dark Grey
    elif [ "$text_color_name" == "background" ] ; then
        COLOR="1;30m";
    #Light Blue with Blue background
    elif [ "$text_color_name" == "policy" ] ; then
        COLOR="44m\e[96m";
    #Red
    elif [ "$text_color_name" == "danger" ] ; then
        COLOR="91m";
    #Blinking Red
    elif [ "$text_color_name" == "blink red" ] ; then
        COLOR="5m\e[91m";
    #Blinking Yellow
    elif [ "$text_color_name" == "blink yellow" ] ; then
        COLOR="5m\e[93m";
    #Default color
    else 
        COLOR="0m";
    fi

    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";

    printf "$STARTCOLOR%b$ENDCOLOR\n" "$text";
}

quiet_output () {
    eval "$1" 2>&1 > /dev/null
}

#prints text in "background" color
bg_str () {
    local command="$1"
    print_style "$command" "background"
}

#prints command results in "background" color
bg_cmd () {
    local command="$1"
    print_style "$(eval $command)" "background"
}

check_that_packages_are_installed () {
    #Testing that packages are installed
    docker --version;docker_version=$?
    if [[ "$docker_version" != '0' ]]
        then
            print_style "Docker is not installed! Please install and try again." "danger"
            exit 1
        else
            print_style "Docker installed" "success"
    fi

    git --version;git_version=$?
    if [[ "$git_version" != '0' ]]
        then
            print_style "git is not installed! Please install and try again." "danger"
            exit 1
        else
            print_style "git installed" "success"
    fi

    aws --version;aws_version=$?
    if [[ "$aws_version" != '0' ]]
        then
            print_style "aws is not installed! Please install and try again." "danger"
            exit 1
        else
            print_style "aws installed" "success"
    fi


    jq --version;jq_version=$?
    if [[ "$jq_version" != '0' ]]
        then
            print_style "jq is not installed! Please install and try again." "danger"
            exit 1
        else
            print_style "jq installed" "success"
    fi

    brew --version;brew_version=$?
    if [[ "$brew_version" != '0' ]]
        then
            print_style "brew is not installed!" "background"
        else
            print_style "brew installed" "success"
    fi

    node --version;node_version=$?
    if [[ "$node_version" != '0' ]]
        then
            print_style "node is not installed!" "background"
        else
            print_style "node installed" "success"
    fi

    npm list -g cfn-tail;cfntail_version=$?
    if [[ "$cfntail_version" != '0' ]]
        then
            print_style "cfntail is not globally installed! Please install globally and try again." "danger"
            read -r -p "Enter 1 to not install via npm. Press Enter to install via npm: " this_answer
            case $this_answer in
                [1]* ) exit 1;; 
                "" ) npm install -g cfn-tail; break;;
                * ) print_style  "Please answer 1 or Enter" "danger";;
            esac
        else
            print_style "cfntail installed" "success"
            bg_str "Setting AWS_PROFILE varible..."
            export AWS_PROFILE="$PROFILE"
            
    fi
}

create_jenkins_docker_container (){
    #https://www.jenkins.io/doc/book/installing/docker/
    # docker pull jenkins/jenkins
    docker image pull docker:dind
    docker network create jenkins #https://docs.docker.com/network/bridge/

    docker build -t myjenkins-blueocean:1.1 ./docker

    this_container_id=$(docker run --name jenkins-blueocean --rm --detach \
    --network jenkins --env DOCKER_HOST=tcp://docker:2376 \
    --env DOCKER_CERT_PATH=/certs/client --env DOCKER_TLS_VERIFY=1 \
    --publish 8080:8080 --publish 50000:50000 \
    --env CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml \
    --volume jenkins-data:/var/jenkins_home \
    --volume jenkins-docker-certs:/certs/client:ro \
    myjenkins-blueocean:1.1)


    echo $this_container_id
    print_style "Container ID:$this_container_id" "info"




    # print_style "Waiting for Setup Code..." "warning"
    # while true; do
    #     docker exec jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword;tmp=$?
    #     if [[ "$tmp" == '0' ]]
    #         then
    #             break;
    #     fi
    #     sleep 5
    # done

    print_style "Secret Setup Code:$(docker exec jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword)" "info"

    print_style "Visit: http://localhost:8080" "success"
}

prepare_for_build () {
    print_style "Preparing for Build... \n\n" "info"

    check_that_packages_are_installed

    #Pull latest changes from repo
    bg_str "Pulling latest changes..."
    quiet_output "git pull"


}

cfn_init (){

    this_file="${YAMLLOCATION:7}"
    ec2=$(cat $this_file | grep -i "AWS::EC2::Instance")
    if [[ "$ec2" != '' ]]
        then
            aws ec2 describe-key-pairs --key-name $SSH_KEY_NAME
            if [[ "$?" != '0' ]]
                then
                    print_style  "Creating Key Pair..." "background"
                    chmod 744 ./$SSH_KEY_NAME.pem
                    aws ec2 create-key-pair --key-name $SSH_KEY_NAME | jq -r '.KeyMaterial' > $SSH_KEY_NAME.pem
            fi
            chmod 400 $SSH_KEY_NAME.pem
        else
            print_style  "No EC2 Instances Specified! Key Pair Creation Skipped..." "background"
    fi
}

cfn_init_delete () {
    if [[ "$1" == '' ]]
        then
            stack=$STACKNAME
        else
            stack=$1
    fi

    bg_str "Deleting Key Pair"
    aws ec2 delete-key-pair --key-name $SSH_KEY_NAME
    rm -rf ./$SSH_KEY_NAME.pem

    bg_str "Emptying S3 Buckets..."
    these_buckets=$(aws cloudformation describe-stack-resources --stack $stack | jq -r '.StackResources' | jq -r '.[] | select(.ResourceType=="AWS::S3::Bucket") | .PhysicalResourceId')

    for bucket in $these_buckets
        do
            aws s3 rb --force s3://$bucket/
        done
}

#Delete CloudFormation Stack
cfn_delete_stack () {

    if [[ "$1" == '' ]]
        then
            stack=$STACKNAME
        else
            stack=$1
    fi

    print_style  "Deleting Stack..." "danger"

    

    aws cloudformation describe-stacks --stack-name "$stack"
    if [[ "$?" != '0' ]]
        then
            #Exit if the stack does not exist
            print_style  "Stack does not exist!" "danger"
    fi

    aws cloudformation delete-stack --stack-name "$stack"

    cfn-tail --region $REGION $stack
}

get_cfn_stack_issue () {
    #Stack name
    print_style  "[$1] Stack Issue Info:" "danger"
    aws cloudformation describe-stack-events --stack $1 | jq -r '.StackEvents | .[] | select((.ResourceStatus=="CREATE_FAILED") or .ResourceStatus=="UPDATE_FAILED") | {LogicalResourceId, ResourceStatus, ResourceStatusReason}'
}

#Update CloudFormation Stack
cfn_update_stack () {
    #stack_name, yaml_location, yaml_param_location

    print_style  "Updating Stack $1..." "info"

    aws cloudformation update-stack --stack-name "$1" --template-body $2  --parameters "$3" --capabilities CAPABILITY_NAMED_IAM
    # quiet_output ""
    
    cfn-tail --region $REGION $1
    if [[ "$?" != '0' ]]
        then
            get_cfn_stack_issue $1
            status=$(aws cloudformation describe-stacks --stack $1 | jq -r '.Stacks | .[].StackStatus')

            while true; do
                read -r -p "[$status] Issues exist. Enter 1 to delete the stack, 2 to try updating, 3 to exit, Enter to continue: " answer
                case $answer in
                    [1]* ) cfn_delete_stack "$1"; exit 1; break;;
                    [2]* ) cfn_update_stack "$1" "$2" "$3"; break;;
                    [3]* ) exit 1;;
                    "" ) bg_str "Continue..."; break;;
                    * ) echo "Please answer 1, 2, or Enter";;
                esac
            done
    fi

}

#Create CloudFormation Stack
cfn_create_stack () {

    aws cloudformation describe-stacks --stack-name "$1" --max-items 1 

    if [[ "$?" != '0' ]]
        then
            print_style  "Creating Stack $1..." "info"
            quiet_output "aws cloudformation create-stack --stack-name $1 --template-body $2 --capabilities CAPABILITY_NAMED_IAM --parameters '$3'"

            cfn-tail --region $REGION $1

            if [[ "$?" != '0' ]]
                then
                    get_cfn_stack_issue $1
                    status=$(aws cloudformation describe-stacks --stack $1 | jq -r '.Stacks | .[].StackStatus')

                    if [[ "$status" == 'ROLLBACK_COMPLETE' ]]
                        then
                            print_style  "Stack $1 Failed! Deleting and exiting..." "danger"
                            cfn_delete_stack $1; exit 1
                    fi

                    while true; do
                        read -r -p "[$status] Issues exist. Enter 1 to delete the stack, 2 to try updating, 3 to exit, Enter to continue: " answer
                        case $answer in
                            [1]* ) cfn_delete_stack $1; exit 1; break;;
                            [2]* ) cfn_update_stack "$1" "$2" "$3"; break;;
                            [3]* ) exit 1;;
                            "" ) bg_str "Continue..."; break;;
                            * ) echo "Please answer 1, 2, 3, or Enter";;
                        esac
                    done

            fi
        else
            print_style  "Stack $1 already exists! Updating stack..." "info"
            cfn_update_stack "$1" "$2" "$3"
    fi

}

get_current_git_commit (){
    git show --oneline -s | head -n1 | cut -d " " -f1
}

get_current_git_comment (){
    git log -1 --format=%s
     
}

get_current_git_branch (){
    git rev-parse --abbrev-ref HEAD
     
}

get_current_date_time (){
    date
}

tests_pipeline () {
    print_style "Starting Tests..." "info"
    
    get_current_git_commit
    get_current_git_comment
    get_current_git_branch
    get_current_date_time

    print_style "Finished Tests..." "success"
}

pipeline_loop () {
    while true; do
        cfn_init

        #Update parameters
        this_params=$(cat ${YAMLPARAMSLOCATION:7} | jq -r ". += [{\"ParameterKey\": \"GitCommit\",\"ParameterValue\": \"$(get_current_git_commit)\"},{\"ParameterKey\": \"GitBranch\",\"ParameterValue\": \"$(get_current_git_branch)\"}]")

        cfn_create_stack $STACKNAME-Pipeline $YAMLLOCATION "$this_params"
        tests_pipeline
        read -r -p "Enter 1 to delete the stack, 2 to update stack + test again, Enter to exit: " answer
        case $answer in
            [1]* ) cfn_init_delete $STACKNAME-Pipeline; cfn_init_delete $STACKNAME-Pipeline-App-Stage; cfn_delete_stack $STACKNAME-Pipeline-App-Stage; cfn_init_delete $STACKNAME-Pipeline-App-Prod; cfn_delete_stack $STACKNAME-Pipeline-App-Prod; cfn_delete_stack $STACKNAME-Pipeline; exit 1;;
            [2]* ) : ;;
            "" ) exit 1;;
            * ) print_style  "Please answer 1, 2, or Enter" "danger";;
        esac
    done
}

tests_app () {
    print_style "Starting Tests..." "info"
    
    get_current_git_commit
    get_current_git_comment
    get_current_git_branch
    get_current_date_time

    print_style "Finished Tests..." "success"
}

app_loop () {
    while true; do
        cfn_init

        #Update parameters
        this_params=$(cat ${YAMLPARAMSLOCATION:7} | jq -r ". += [{\"ParameterKey\": \"GitCommit\",\"ParameterValue\": \"$(get_current_git_commit)\"},{\"ParameterKey\": \"GitComment\",\"ParameterValue\": \"$(get_current_git_comment)\"},{\"ParameterKey\": \"GitBranch\",\"ParameterValue\": \"$(get_current_git_branch)\"},{\"ParameterKey\": \"LaunchTime\",\"ParameterValue\": \"$(get_current_date_time)\"}]")

        cfn_create_stack $STACKNAME-app $YAMLLOCATIONAPP "$this_params"
        tests_app
        read -r -p "Enter 1 to delete the stack, 2 to update stack + test again, Enter to exit: " answer
        case $answer in
            [1]* ) cfn_init_delete $STACKNAME-app; cfn_delete_stack $STACKNAME-app; exit 1;;
            [2]* ) : ;;
            "" ) exit 1;;
            * ) print_style  "Please answer 1, 2, or Enter" "danger";;
        esac
    done
}

prepare_for_build


# #Function to just run tests
# if [[ "$1" == 't' ]]
#     then
#         while true; do
#             tests
#             read -r -p "Enter 1 to delete the stack, 2 to exit, Enter to test again: [To make changes, please exit and run tests again without 't' flag!]" answer
#             case $answer in
#                 [1]* ) cfn_init_delete; cfn_delete_stack; exit 1;;
#                 [2]* ) exit 1 ;;
#                 "" ) : ;;
#                 * ) print_style  "Please answer 1, 2, or Enter" "danger";;
#             esac
#         done
# fi

#Function to delete all stacks
if [[ "$1" == 'delete' ]]
    then
        cfn_init_delete $STACKNAME-Pipeline; cfn_init_delete $STACKNAME-Pipeline-App-Stage; cfn_delete_stack $STACKNAME-Pipeline-App-Stage; cfn_init_delete $STACKNAME-Pipeline-App-Prod; cfn_delete_stack $STACKNAME-Pipeline-App-Prod; cfn_delete_stack $STACKNAME-Pipeline; exit 1
fi

pipeline_loop

# read -r -p "Enter 1 to deploy pipeline, 2 to deploy application stack, Enter to exit: " answer
# case $answer in
#     [1]* ) pipeline_loop ;;
#     [2]* ) app_loop ;;
#     "" ) exit 1;;
#     * ) print_style  "Please answer 1, 2, or Enter" "danger";;
# esac


# #Main Loop
# while true; do
#     cfn_init

#     #Update parameters
#     this_params=$(cat ${YAMLPARAMSLOCATION:7} | jq -r ". += [{\"ParameterKey\": \"GitCommit\",\"ParameterValue\": \"$(get_current_git_commit)\"},{\"ParameterKey\": \"GitComment\",\"ParameterValue\": \"$(get_current_git_comment)\"},{\"ParameterKey\": \"GitBranch\",\"ParameterValue\": \"$(get_current_git_branch)\"},{\"ParameterKey\": \"LaunchTime\",\"ParameterValue\": \"$(get_current_date_time)\"}]")

#     cfn_create_stack $STACKNAME $YAMLLOCATION "$this_params"
#     tests
#     read -r -p "Enter 1 to delete the stack, 2 to update stack + test again, Enter to exit: " answer
#     case $answer in
#         [1]* ) cfn_init_delete; cfn_delete_stack; exit 1;;
#         [2]* ) : ;;
#         "" ) exit 1;;
#         * ) print_style  "Please answer 1, 2, or Enter" "danger";;
#     esac
# done