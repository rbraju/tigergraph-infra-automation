pipeline {
    agent any
    environment {
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

                    // Create namespace if it doesn't exist
                    sh './kubectl --kubeconfig=${KUBECONFIG_FILE} create namespace tigergraph --dry-run=client -o yaml | ./kubectl --kubeconfig=${KUBECONFIG_FILE} apply -f -'

                    // Apply the manifest
                    sh './kubectl --kubeconfig=${KUBECONFIG_FILE} apply -f k8s/tigergraph-setup.yml'
            
                }
            }
        }
        stage('Health Check') {
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    // Wait until ALL pods with the label 'tigergraph' are ready.
                    echo "Waiting for all pods to be ready..."
                    sh "./kubectl --kubeconfig=${KUBECONFIG_FILE} wait --for=condition=Ready pod -l app=tigergraph -n tigergraph --timeout=300s"
                }
            }
        }
        stage('Setup SSH Access') {
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    echo "Setting up SSH access..."
                    sh '''
                    # Get the public key from tg-0 pod
                    PUB_KEY=\$(./kubectl --kubeconfig=\$KUBECONFIG_FILE exec tg-0 -n tigergraph -- cat /home/tigergraph/.ssh/id_rsa.pub)

                    # Append it to the authorized keys on tg-1 and tg-2
                    DOMAIN="tg-svc.tigergraph.svc.cluster.local"
                    for i in 1 2; do
                        POD_NAME="tg-\${i}"
                        POD_FQDN="\${POD_NAME}.\${DOMAIN}"
                        echo "Setting up SSH trust for \${POD_NAME} (\${POD_FQDN})..."
                        ./kubectl --kubeconfig=\$KUBECONFIG_FILE exec \${POD_NAME} -n tigergraph -- bash -c "echo '\$PUB_KEY' >> /home/tigergraph/.ssh/authorized_keys"
                        ./kubectl --kubeconfig=\$KUBECONFIG_FILE exec \${POD_NAME} -n tigergraph -- bash -c "chmod 600 /home/tigergraph/.ssh/authorized_keys"

                        # Pre scan host keys to prevent "Host authenticity" prompts
                        ./kubectl --kubeconfig=\$KUBECONFIG_FILE exec tg-0 -n tigergraph -- bash -c "ssh-keyscan \${POD_FQDN} >> /home/tigergraph/.ssh/known_hosts"
                    done
                    '''
                }
            }
        }
    }
}
