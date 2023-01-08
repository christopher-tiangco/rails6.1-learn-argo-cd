#!/bin/bash

# Shell script to generate Sealed secrets k8s manifest using GitHub Secrets

# NOTES:
# - This script is exclusively used for GitHub Actions workflow and will NOT run outside of that context
# - Uses yq to parse secrets_mapping.yaml and creates a Sealed secrets k8s manifests
# - Uses jq to parse GitHub secrets context object
# - Uses kubeseal encrypter for encrypting a string
# - Relies on the existence of environment variables set in the GitHub Actions workflow invoking this shell script.
#   - A GitHub Actions workflow has to handle sending the secrets to the runner environment

# @TODO: Error checking - throw an error if any of the following does not exist
# - secrets_mapping.yaml
# - $TMP_DIR
# - $SEALED_SECRET_CONTROLLER_CERT
# - $K8S_NAMESPACE

generated_sealed_secrets_counter=0

# Get all the secret names from the mapping then store to array
secret_names=( $(yq 'keys | .[]' secrets_mapping.yaml) )

for i in "${secret_names[@]}"
do
  sealed_secret_file_updated=false
  data_length=$(yq ".$i.data | length" secrets_mapping.yaml)
  target_filename=$(yq ".$i.sealed_secret_manifest_filename" secrets_mapping.yaml)
  
  #@TODO: Skip this iteration if sealed secret template (as specified by the target_filename) does not exist

  for (( j=0; j<$data_length; j++ ))
  do
    gh_secret_name=$(yq ".$i.data.[$j].gh_secret_name" secrets_mapping.yaml)
    gh_secret_env_value=$(eval echo '$'$gh_secret_name)

    [[ "$gh_secret_env_value" == "" ]] && continue

    target_placeholder=$(yq ".$i.data.[$j].target_placeholder" secrets_mapping.yaml)
    sealed_secret=$(echo -n "$gh_secret_env_value" | kubeseal --cert $TMP_DIR/$SEALED_SECRET_CONTROLLER_CERT --raw --namespace $K8S_NAMESPACE --name $i | sed 's;/;\\/;g')

    #@TODO: Echo contents of sealed secret template, then using `sed` replace target_placeholder with sealed_secret then output to a file at app/manifest
    sealed_secret_file_updated=true
  done
  
  #@TODO: If sealed_secret_file_updated, increment generated_sealed_secrets_counter
done

echo "Generated / Updated $generated_sealed_secrets_counter sealed secret manifests"
