#!/bin/bash

# Shell script to generate Sealed secrets k8s manifest using GitHub Secrets

# NOTES:
# - This script is exclusively used for GitHub Actions workflow and will NOT run outside of that context
# - Uses yq to parse secrets_mapping.yaml and creates a Sealed secrets k8s manifests
# - Uses jq to parse GitHub secrets context object
# - Uses kubeseal encrypter for encrypting a string
# - Relies on the existence of environment variables set in the GitHub Actions workflow invoking this shell script.
#   - A GitHub Actions workflow has to handle sending the secrets to the runner environment as well as generating temporary files for the public
#     certificate

mapping_file='secrets_mapping.yaml'

# Error checking - throw an error if any of the following does not exist
if [ ! -f $mapping_file ]; then
  echo "$mapping_file DOES NOT exist"
  exit 1
fi
if [ ! -d $TMP_DIR ]; then
  echo "$TMP_DIR DOES NOT exist"
  exit 1
fi
if [ ! -f $TMP_DIR/$SEALED_SECRET_CONTROLLER_CERT ]; then
  echo "$SEALED_SECRET_CONTROLLER_CERT DOES NOT exist"
  exit 1
fi
if [ "$APP_SEALED_SECRET_TEMPLATES_DIR" == "" ] || [ ! -d $APP_SEALED_SECRET_TEMPLATES_DIR ]; then
  echo "$APP_SEALED_SECRET_TEMPLATES_DIR DOES NOT exist"
  exit 1
fi
if [ "$K8S_NAMESPACE" == "" ]; then
  echo "\$K8S_NAMESPACE is NOT set"
  exit 1
fi

generated_sealed_secrets_counter=0

# Get all the secret names from the mapping then store to array
secret_names=( $(yq 'keys | .[]' $mapping_file) )

for i in "${secret_names[@]}"
do
  sealed_secret_file_updated=false
  data_length=$(yq ".$i.data | length" $mapping_file)
  target_filename=$(yq ".$i.sealed_secret_manifest_filename" $mapping_file)
  
  # Skip this iteration if sealed secret template (as specified by the target_filename) does not exist
  [[ ! -f $APP_SEALED_SECRET_TEMPLATES_DIR/$target_filename ]] && continue

  for (( j=0; j<$data_length; j++ ))
  do
    gh_secret_name=$(yq ".$i.data.[$j].gh_secret_name" $mapping_file)
    gh_secret_env_value=$(eval echo '$'$gh_secret_name)

    [[ "$gh_secret_env_value" == "" ]] && continue

    target_placeholder=$(yq ".$i.data.[$j].target_placeholder" $mapping_file)
    sealed_secret=$(echo -n "$gh_secret_env_value" | kubeseal --cert $TMP_DIR/$SEALED_SECRET_CONTROLLER_CERT --raw --namespace $K8S_NAMESPACE --name $i | sed 's;/;\\/;g')

    #@TODO: Echo contents of sealed secret template, then using `sed` replace target_placeholder with sealed_secret then output to a file at app/manifest
    sealed_secret_file_updated=true
  done
  
  [ $sealed_secret_file_updated == true ] && (($generated_sealed_secrets_counter++))
done

echo "Generated / Updated $generated_sealed_secrets_counter sealed secret manifests"
