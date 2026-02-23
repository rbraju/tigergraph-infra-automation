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
                    ./kubectl --kubeconfig=${KUBECONFIG_FILE} wait --for=condition=Ready pod/tg-0 -n ${TG_NAMESPACE} --timeout=300s
                    '''

                    // // Wait until ALL pods with the label 'tigergraph' are ready.
                    // echo "Waiting for every pod to be ready..."
                    // sh '''
                    // for i in 0 1 2; do
                    //     ./kubectl --kubeconfig=${KUBECONFIG_FILE} wait --for=condition=Ready pod/tg-$i -n ${TG_NAMESPACE} --timeout=300s
                    // done
                    // '''
                }
            }
        }
        stage('Setup SSH Access') {
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    echo "Setting up SSH access..."
                    sh 'chmod +x ./scripts/setup_ssh.sh'
                    sh './scripts/setup_ssh.sh'
                }
            }
        }
        stage('Initialize TigerGraph') {
            environment {
                TG_LICENSE_KEY = credentials('tg-license-key')
            }
            steps {
                withCredentials([file(credentialsId: KUBE_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                    echo "Initializing TigerGraph..."
                    sh 'chmod +x scripts/init_tigergraph.sh'
                    sh './scripts/init_tigergraph.sh'
                }
            }
        }
    }
}
