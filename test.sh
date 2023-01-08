#!/bin/bash

sealed_secret=$(echo -n ${{ secrets.RAILS_MASTER_KEY }} | kubeseal --cert ${{ env.TMP_DIR }}/${{ env.SEALED_SECRET_CONTROLLER_CERT }} --raw --namespace ${{ env.K8S_NAMESPACE }} --name rails-master-key | sed 's;/;\\/;g')
echo $sealed_secret > file1
