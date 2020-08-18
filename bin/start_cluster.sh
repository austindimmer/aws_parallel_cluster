#!/bin/bash

# Functions
echo_stderr(){
    # Write log to stderr
    echo "${@}" 1>&2
}

display_help() {
    # Display help message then exit
    echo_stderr "Usage: $0 NAME_OF_YOUR_CLUSTER --cluster-template CLUSTER_TEMPLATE"
}

# Get args
while [ $# -gt 0 ]; do
    case "$1" in
        --cluster-template)
          cluster_template="$2"
          shift 1
          ;;
        --config)
          config_file="$2"
          shift 1
          ;;
        --extra-parameters)
          extra_parameters="$2"
          shift 1
          ;;
        --help)
          display_help
          exit 0
          ;;
        *)
          # Single positional argument
          cluster_name_arg="$1"
        ;;
    esac
    shift
done


# Check config file, set config_file_arg param
if [[ -z "${config_file}" ]]; then
    echo_stderr "--config not specified, defaulting to conf/config"
    config_file="conf/config"
fi

if [[ ! -f "${config_file}" ]]; then
    echo_stderr "Could not find path to config file, exiting"
    exit 1
fi

config_file_arg="--config=${config_file}"

# Check cluster_template argument
if [[ -z "${cluster_template}" ]]; then
    echo_stderr "--cluster-template not specified, using default in config"
    cluster_template_arg=""
else
    cluster_template_arg="--cluster-template=${cluster_template}"
fi

# Check extra parameters argument
if [[ -z "${extra_parameters}" ]]; then
  extra_parameters_arg=""
else
  extra_parameters_arg="--extra-parameters=${extra_parameters}"
fi

# Ensure cluster-name is set
if [[ "${cluster_name_arg}" && "${cluster_template_arg}" ]]; then
    echo_stderr "Running the following command:"
    echo "pcluster create \
                 ${cluster_name_arg} \
                 ${config_file_arg} \
                 ${cluster_template_arg} \
                 --tags \"{\\\"Creator\\\": \\\"${USER}\\\"}\"" | \
       sed -e's/  */ /g' 1>&2
    # Initialise the cluster
    pcluster create \
      "${cluster_name_arg}" \
      "${config_file_arg}" \
      "${cluster_template_arg}" \
      --tags "{\"Creator\": \"${USER}\"}"
    # FIXME removed --no-rollback argument due to compute nodes not starting up as required.
    # Need to investigate further before determining this is the cause of the issue

    # Check if creation was successful
	  if [[ "$?" == "0" ]]; then
      echo_stderr "Stack creation succeeded - now retrieving name of IP"
      exit 0
    else
      echo_stderr "Could not create the parallel cluster stack, exiting"
      exit 1
    fi

    # Output the master IP to log
    # FIXME - this doesn't print out the instance ID
    # Could be because the instance hasn't started running at this point.
    echo_stderr "$(aws ec2 describe-instances \
                     --query "Reservations[*].Instances[*].[InstanceId]" \
                     --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=Master" \
                     --output text)"

	  # FIXME: control error codes better, avoiding counterintuitive ones: i.e authed within a different account:
	  # ERROR: The configuration parameter 'vpc_id' generated the following errors:
	  # The vpc ID 'vpc-7d2b2e1a' does not exist
	  # OR ERROR:  The following resource(s) failed to create: [MasterServerWaitCondition, ComputeFleet].
else
    display_help
fi
