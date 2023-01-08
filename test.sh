#!/bin/bash

sealed_secret=$(echo -n $RAILS_MASTER_KEY | kubeseal --cert $TMP_DIR/$SEALED_SECRET_CONTROLLER_CERT --raw --namespace $K8S_NAMESPACE --name rails-master-key | sed 's;/;\\/;g')
echo $sealed_secret > file1
