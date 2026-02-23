#!/bin/bash

# Generate a new SSH key locally, in the jenkins workspace
echo "y" | ssh-keygen -t rsa -b 4096 -f ./id_rsa -N ""

PUBLIC_KEY=$(cat ./id_rsa.pub)
PRIVATE_KEY=$(cat ./id_rsa)

#for i in 0 1 2; do
i=0
POD_NAME="tg-$i"
echo "Injecting public key into $POD_NAME..."

# Create .ssh folder
./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "echo '$PUBLIC_KEY' > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "echo '$PRIVATE_KEY' > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa"

# Fix Host Key Checking (The "StrictHostKeyChecking" fix)
./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "echo -e 'Host *\\n  StrictHostKeyChecking no\\n  UserKnownHostsFile /dev/null' > ~/.ssh/config && chmod 600 ~/.ssh/config"

# Set ownership to tigergraph user just in case
./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "chown -R tigergraph:tigergraph ~/.ssh"

echo "SSH access setup complete for $POD_NAME."
#done
