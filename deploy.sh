#!/bin/bash

#
# *** Purpose ***
# To create or destroy the infrastructure for the Confluent AWS Egress PrivateLink Infrastructure & Networking example.
#
# *** Script Syntax ***
# ./deploy.sh=<create | destroy> --profile=<SSO_PROFILE_NAME>
#                                --confluent-api-key=<CONFLUENT_API_KEY>
#                                --confluent-api-secret=<CONFLUENT_API_SECRET>
#                                --confluent-environment-id=<CONFLUENT_ENVIRONMENT_ID>
#                                --database-vpc-id=<DATABASE_VPC_ID>
#                                --database-subnet-ids=<DATABASE_SUBNET_IDS_COMMA_SEPARATED>
#                                --database-private-ip=<DATABASE_PRIVATE_IP>
#                                --database-port=<DATABASE_PORT>
#                                --database-domain=<DATABASE_DOMAIN>
#
#


set -euo pipefail  # Stop on error, undefined variables, and pipeline errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NO_COLOR='\033[0m'

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NO_COLOR} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NO_COLOR} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NO_COLOR} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NO_COLOR} $1"
}

# Configuration folders
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

print_info "Terraform Directory: $TERRAFORM_DIR"

argument_list="--profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET> --confluent-environment-id=<CONFLUENT_ENVIRONMENT_ID> --database-vpc-id=<DATABASE_VPC_ID> --database-subnet-ids=<DATABASE_SUBNET_IDS_COMMA_SEPARATED> --database-private-ip=<DATABASE_PRIVATE_IP> --database-port=<DATABASE_PORT> --database-domain=<DATABASE_DOMAIN>"

# Check required command (create or destroy) was supplied
case $1 in
  create)
    create_action=true;;
  destroy)
    create_action=false;;
  *)
    echo
    print_error "(Error Message 001)  You did not specify one of the commands: create | destroy."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0`=<create | destroy> $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
    ;;
esac

# Default required variables
AWS_PROFILE=""
confluent_api_key=""
confluent_api_secret=""
confluent_environment_id=""
database_vpc_id=""
database_subnet_ids=""
database_private_ip=""
database_port=""
database_domain=""

# Get the arguments passed by shift to remove the first word
# then iterate over the rest of the arguments
shift
for arg in "$@" # $@ sees arguments as separate words
do
    case $arg in
        *"--profile="*)
            AWS_PROFILE=$arg;;
        *"--confluent-api-key="*)
            arg_length=20
            confluent_api_key=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--confluent-api-secret="*)
            arg_length=23
            confluent_api_secret=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--confluent-environment-id="*)
            arg_length=27
            confluent_environment_id=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--database-vpc-id="*)
            arg_length=18
            database_vpc_id=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--database-subnet-ids="*)
            arg_length=25
            database_subnet_ids=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--database-private-ip="*)
            arg_length=27
            database_private_ip=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--database-port="*)
            arg_length=20
            database_port=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--database-domain="*)
            arg_length=22
            database_domain=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *)
            echo
            print_error "(Error Message 002)  You included an invalid argument: $arg"
            echo
            print_error "Usage:  Require all nine arguments ---> `basename $0`=<create | destroy> $argument_list"
            echo
            exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
            ;;
    esac
done

# Check required --profile argument was supplied
if [ -z "$AWS_PROFILE" ]
then
    echo
    print_error "(Error Message 003)  You did not include the proper use of the --profile=<SSO_PROFILE_NAME> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-key argument was supplied
if [ -z "$confluent_api_key" ]
then
    echo
    print_error "(Error Message 004)  You did not include the proper use of the --confluent-api-key=<CONFLUENT_API_KEY> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-secret argument was supplied
if [ -z "$confluent_api_secret" ]
then
    echo
    print_error "(Error Message 005)  You did not include the proper use of the --confluent-api-secret=<CONFLUENT_API_SECRET> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-environment-id argument was supplied
if [ -z "$confluent_environment_id" ]
then
    echo
    print_error "(Error Message 006)  You did not include the proper use of the --confluent-environment-id=<CONFLUENT_ENVIRONMENT_ID> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --database-vpc-id argument was supplied
if [ -z "$database_vpc_id" ]
then
    echo
    print_error "(Error Message 007)  You did not include the proper use of the --database-vpc-id=<DATABASE_VPC_ID> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --database-subnet-ids argument was supplied
if [ -z "$database_subnet_ids" ]
then
    echo
    print_error "(Error Message 008)  You did not include the proper use of the --database-subnet-ids=<DATABASE_SUBNET_IDS_COMMA_SEPARATED> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --database-private-ip argument was supplied
if [ -z "$database_private_ip" ]
then
    echo
    print_error "(Error Message 009)  You did not include the proper use of the --database-private-ip=<DATABASE_PRIVATE_IP> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --database-port argument was supplied
if [ -z "$database_port" ]
then
    echo
    print_error "(Error Message 010)  You did not include the proper use of the --database-port=<DATABASE_PORT> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --database-domain argument was supplied
if [ -z "$database_domain" ]
then
    echo
    print_error "(Error Message 011)  You did not include the proper use of the --database-domain=<DATABASE_DOMAIN> argument in the call."
    echo
    print_error "Usage:  Require all nine arguments ---> `basename $0 $1` $argument_list"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi


# Get the AWS SSO credential variables that are used by the AWS CLI commands to authenicate
print_step "Authenticating to AWS SSO profile: $AWS_PROFILE..."
aws sso login $AWS_PROFILE
eval $(aws2-wrap $AWS_PROFILE --export)
export AWS_REGION=$(aws configure get region $AWS_PROFILE)


# Function to deploy infrastructure
deploy_infrastructure() {
    print_step "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # UNCOMMENT WHEN YOU WANT TO USE A terraform.tfvars FILE INSTEAD OF ENVIRONMENT VARIABLES
    # Create terraform.tfvars file with the required variables
    # printf "aws_region=\"${AWS_REGION}\"\
    # \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    # \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    # \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    # \nconfluent_api_key=\"${confluent_api_key}\"\
    # \nconfluent_api_secret=\"${confluent_api_secret}\"\
    # \nconfluent_environment_id=\"${confluent_environment_id}\"\
    # \ndatabase_vpc_id=\"${database_vpc_id}\"\
    # \ndatabase_subnet_ids=${database_subnet_ids}\
    # \ndatabase_private_ip=\"${database_private_ip}\"\
    # \ndatabase_port=\"${database_port}\"\
    # \ndatabase_domain=\"${database_domain}\"" > terraform.tfvars

    # Export Terraform variables as environment variables
    export TF_VAR_aws_region="${AWS_REGION}"
    export TF_VAR_aws_access_key_id="${AWS_ACCESS_KEY_ID}"
    export TF_VAR_aws_secret_access_key="${AWS_SECRET_ACCESS_KEY}"
    export TF_VAR_aws_session_token="${AWS_SESSION_TOKEN}"
    export TF_VAR_confluent_api_key="${confluent_api_key}"
    export TF_VAR_confluent_api_secret="${confluent_api_secret}"
    export TF_VAR_confluent_environment_id="${confluent_environment_id}"
    export TF_VAR_database_vpc_id="${database_vpc_id}"
    export TF_VAR_database_subnet_ids="${database_subnet_ids}"
    export TF_VAR_database_private_ip="${database_private_ip}"
    export TF_VAR_database_port="${database_port}"
    export TF_VAR_database_domain="${database_domain}"

    # Initialize Terraform
    print_info "Initializing Terraform..."
    terraform init

    # Plan Terraform
    print_info "Running Terraform plan..."
    terraform plan -out=tfplan > tfplan.out
    
    # Apply Terraform
    read -p "Do you want to apply this plan? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Applying Terraform plan..."

        # Stage 3 Apply: Apply the rest of the infrastructure
        terraform apply tfplan 
        rm tfplan
        print_info "Infrastructure deployed successfully!"

        print_info "Creating the Terraform visualization..."
        terraform graph | dot -Tpng > ../docs/images/terraform-visualization.png
        print_info "Terraform visualization created at: ../docs/images/terraform-visualization.png"
        cd ..
        return 0
    else
        print_warn "Deployment cancelled"
        rm tfplan
        return 1
    fi
}

# Function to undeploy infrastructure
undeploy_infrastructure() {
    print_step "Destroying infrastructure with Terraform..."

    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform if needed
    print_info "Initializing Terraform..."
    terraform init
    
    # Export Terraform variables as environment variables
    export TF_VAR_aws_region="${AWS_REGION}"
    export TF_VAR_aws_access_key_id="${AWS_ACCESS_KEY_ID}"
    export TF_VAR_aws_secret_access_key="${AWS_SECRET_ACCESS_KEY}"
    export TF_VAR_aws_session_token="${AWS_SESSION_TOKEN}"
    export TF_VAR_confluent_api_key="${confluent_api_key}"
    export TF_VAR_confluent_api_secret="${confluent_api_secret}"
    export TF_VAR_confluent_environment_id="${confluent_environment_id}"
    export TF_VAR_database_vpc_id="${database_vpc_id}"
    export TF_VAR_database_subnet_ids="${database_subnet_ids}"
    export TF_VAR_database_private_ip="${database_private_ip}"
    export TF_VAR_database_port="${database_port}"
    export TF_VAR_database_domain="${database_domain}"
    
    # Destroy
    print_info "Running Terraform destroy..."
    
    # Auto approves the destroy plan without prompting, and destroys based on state only, without
    # trying to refresh data sources
    terraform destroy -auto-approve
    
    print_info "Infrastructure destroyed successfully!"

    print_info "Creating the Terraform visualization..."
    terraform graph | dot -Tpng > ../docs/images/terraform-visualization.png
    print_info "Terraform visualization created at: ../docs/images/terraform-visualization.png"
    cd ..
}   

# Main execution flow
if [ "$create_action" = true ]
then
    deploy_infrastructure
else
    undeploy_infrastructure
    exit 0
fi
