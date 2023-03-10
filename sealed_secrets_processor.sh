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
if [ "$TMP_DIR" == "" ] || [ ! -d $TMP_DIR ]; then
  echo "TMP_DIR environment variable DOES NOT exist or invalid path"
  exit 1
fi
if [ "$SEALED_SECRET_CONTROLLER_CERT" == "" ] || [ ! -f $TMP_DIR/$SEALED_SECRET_CONTROLLER_CERT ]; then
  echo "SEALED_SECRET_CONTROLLER_CERT environment variable DOES NOT exist or invalid filename"
  exit 1
fi
if [ "$APP_MANIFEST_DIR" == "" ] || [ ! -d $APP_MANIFEST_DIR ]; then
  echo "APP_MANIFEST_DIR environment variable DOES NOT exist or invalid path"
  exit 1
fi
if [ "$APP_SEALED_SECRET_TEMPLATES_DIR" == "" ] || [ ! -d $APP_SEALED_SECRET_TEMPLATES_DIR ]; then
  echo "APP_SEALED_SECRET_TEMPLATES_DIR environment variable DOES NOT exist or invalid path"
  exit 1
fi
if [ "$K8S_NAMESPACE" == "" ]; then
  echo "K8S_NAMESPACE environment variable DOES NOT exist"
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
  
  # Copy the template file into a temporary directory. This copied file will have the string replacements
  cp $APP_SEALED_SECRET_TEMPLATES_DIR/$target_filename $TMP_DIR

  for (( j=0; j<$data_length; j++ ))
  do
    gh_secret_name=$(yq ".$i.data.[$j].gh_secret_name" $mapping_file)
    gh_secret_env_value=$(eval echo '$'$gh_secret_name)

    # Skip this iteration if GitHub secret does not exist
    [[ "$gh_secret_env_value" == "" ]] && continue

    target_placeholder=$(yq ".$i.data.[$j].target_placeholder" $mapping_file)
    sealed_secret=$(echo -n "$gh_secret_env_value" | kubeseal --cert $TMP_DIR/$SEALED_SECRET_CONTROLLER_CERT --raw --namespace $K8S_NAMESPACE --name $i | sed 's;/;\\/;g')

    # Using `sed` replace target_placeholder with sealed_secret in the temporary template file
    sed -i "s/$target_placeholder/$sealed_secret/g" $TMP_DIR/$target_filename
    sealed_secret_file_updated=true
  done
  
  if [ $sealed_secret_file_updated == true ]; then
    cp $TMP_DIR/$target_filename $APP_MANIFEST_DIR/$target_filename
    ((generated_sealed_secrets_counter++))
  fi
done

echo "Generated / Updated $generated_sealed_secrets_counter sealed secret manifests"
