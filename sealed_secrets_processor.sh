#!/bin/bash

# Shell script to generate Sealed secrets k8s manifest using GitHub Secrets

# NOTES:
# - This script is exclusively used for GitHub Actions workflow and will NOT run outside of that context
# - Uses yq to parse secrets_mapping.yaml and creates a Sealed secrets k8s manifests
# - Uses jq to parse GitHub secrets context object
# - Uses kubeseal encrypter for encrypting a string
# - Relies on the existence of environment variables set in the GitHub Actions workflow invoking this shell script

# Get all the secret names from the mapping then store to array
secret_names=( $(yq 'keys | .[]' secrets_mapping.yaml) )

for i in "${secret_names[@]}"
do
  data_length=$(yq ".$i.data | length" secrets_mapping.yaml)
  target_filename=$(yq ".$i.sealed_secret_manifest_filename" secrets_mapping.yaml)

  for (( j=0; j<$data_length; j++ ))
  do
    gh_secret_name=$(yq ".$i.data.[$j].gh_secret_name" secrets_mapping.yaml)

    [[ "\$$gh_secret_name" == "" ]] && echo "env var non existent" || echo "env var exists!!!"

    target_placeholder=$(yq ".$i.data.[$j].target_placeholder" secrets_mapping.yaml)
    sealed_secret=$(echo -n "\$$gh_secret_name" | kubeseal --cert $TMP_DIR/$SEALED_SECRET_CONTROLLER_CERT --raw --namespace $K8S_NAMESPACE --name $i | sed 's;/;\\/;g')

    echo "\$$gh_secret_name"
    printf "\n"
    echo "Processing $i for $gh_secret_name..."

    printf "\n\n"
  done
  printf "\n\n"
done
