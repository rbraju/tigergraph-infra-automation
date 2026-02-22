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
                    sh "./kubectl --kubeconfig=${KUBECONFIG_FILE} create namespace tigergraph --dry-run=client -o yaml | ./kubectl --kubeconfig=${KUBECONFIG_FILE} apply -f -"

                    // Apply the manifest
                    sh "./kubectl --kubeconfig=${KUBECONFIG_FILE} apply -f k8s/tigergraph-setup.yaml"
            
                }
            }
        }
        stage('Health Check') {
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    echo "Waiting for TigerGraph to be ready..."
                    sh "./kubectl --kubeconfig=${KUBECONFIG_FILE} wait --for=condition=Ready pod/tg-0 -n tigergraph --timeout=180s"
                }
            }
        }
    }
}
