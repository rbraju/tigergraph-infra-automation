pipeline {
    agent any
    environment {
        TG_NAMESPACE = 'tigergraph'
        KUBE_CREDENTIAL_ID = 'tg-infra-kubeconfig'
    }
    stages {
        stage('Environment Setup') {
            steps {
                sh '''
                if ! command -v kubectl &> /dev/null; then
                    echo "kubectl not found. Installing..."
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                fi
                '''
            }
        }
        stage('Deploy TigerGraph') {
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    echo "Deploying TigerGraph..."

                    echo "Deleting namespace if it exists..."
                    sh './kubectl --kubeconfig=${KUBECONFIG_FILE} delete namespace ${TG_NAMESPACE} --grace-period=0 --force'

                    // Create namespace if it doesn't exist
                    sh './kubectl --kubeconfig=${KUBECONFIG_FILE} create namespace ${TG_NAMESPACE} --dry-run=client -o yaml | ./kubectl --kubeconfig=${KUBECONFIG_FILE} apply -f -'

                    // Apply the manifest
                    sh './kubectl --kubeconfig=${KUBECONFIG_FILE} apply -f k8s/tigergraph-setup.yml'
            
                }
            }
        }
        stage('Health Check') {
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    // Wait until ALL pods with the label 'tigergraph' are ready.
                    echo "Waiting for every pod to be ready..."
                    sh '''
                    for i in 0 1 2; do
                        ./kubectl --kubeconfig=${KUBECONFIG_FILE} wait --for=condition=Ready pod/tg-$i -n ${TG_NAMESPACE} --timeout=300s
                    done
                    '''
                }
            }
        }
        stage('Setup SSH Access') {
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    echo "Setting up SSH access..."
                    sh '''
                    # Generate a new SSH key locally, in the jenkins workspace
                    echo "y" | ssh-keygen -t rsa -b 4096 -f ./id_rsa -N ""

                    PUBLIC_KEY=$(cat ./id_rsa.pub)
                    PRIVATE_KEY=$(cat ./id_rsa)

                    for i in 0 1 2; do
                        POD_NAME="tg-$i"
                        echo "Injecting public key into $POD_NAME..."

                        # Create .ssh folder
                        ./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
                        ./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "echo '$PUBLIC_KEY' > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
                        ./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "echo '$PRIVATE_KEY' > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa"

                        # Fix Host Key Checking (The "StrictHostKeyChecking" fix)
                        ./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "echo -e 'Host *\\\\n  StrictHostKeyChecking no\\\\n  UserKnownHostsFile /dev/null' > ~/.ssh/config && chmod 600 ~/.ssh/config"
                        
                        # Set ownership to tigergraph user just in case
                        ./kubectl --kubeconfig=$KUBECONFIG_FILE exec $POD_NAME -n ${TG_NAMESPACE} -- bash -c "chown -R tigergraph:tigergraph ~/.ssh"

                        echo "SSH access setup complete for $POD_NAME."
                    done
                    '''
                }
            }
        }
        stage('Apply License') {
            environment {
                TG_LICENSE_KEY = credentials('tg-license-key')
            }
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    echo "Applying TigerGraph license and restarting all services..."
                    sh """
                    # Set the license
                    echo "Running as user: \$(whoami)"
                    echo "Hostname: \$(hostname -f)"

                    # Add license
                    ./kubectl --kubeconfig=$KUBECONFIG_FILE exec tg-0 -n ${TG_NAMESPACE} -- /home/tigergraph/tigergraph/app/cmd/gadmin license set $TG_LICENSE_KEY

                    # Replace loopback ip with actual hostname
                    tg_hostname="tg-0.tg-svc.${TG_NAMESPACE}.svc.cluster.local"
                    ./kubectl --kubeconfig=$KUBECONFIG_FILE exec tg-0 -n tigergraph -- \
                    /home/tigergraph/tigergraph/app/cmd/gadmin config \
                    set System.HostList "[{\\"Hostname\\":\\"${tg_hostname}",\\"ID\\":\\"m1\\",\\"Region\\":\\"\\"}]"

                    # Apply the configand restart all services
                    ./kubectl --kubeconfig=$KUBECONFIG_FILE exec tg-0 -n tigergraph -- /home/tigergraph/tigergraph/app/cmd/gadmin config apply -y
                    ./kubectl --kubeconfig=$KUBECONFIG_FILE exec tg-0 -n tigergraph -- /home/tigergraph/tigergraph/app/cmd/gadmin restart all -y
                    """
                }
            }
        }
    }
}
