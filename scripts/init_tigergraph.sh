#!/bin/bash

GSQL_CMD="/home/tigergraph/tigergraph/app/cmd/gsql"
GADMIN_CMD="/home/tigergraph/tigergraph/app/cmd/gadmin"
TARGET_FQDN="tg-0.tg-svc.${TG_NAMESPACE}.svc.cluster.local"
KUBECTL_EXEC="./kubectl --kubeconfig=$KUBECONFIG_FILE exec tg-0 -n $TG_NAMESPACE"
SEPARATOR="----------------------------------------------------------------------------------"

echo "--- Waiting for Controller to respond ---"
for i in {1..15}; do
    if $KUBECTL_EXEC -- $GADMIN_CMD version > /dev/null 2>&1; then
        echo "Controller is UP."
        break
    fi
    echo "Waiting for controller... (Attempt $i/15)"
    sleep 10
done

echo $SEPARATOR
echo "Setting license..."
$KUBECTL_EXEC -- $GADMIN_CMD license set "$TG_LICENSE_KEY"
$KUBECTL_EXEC -- $GADMIN_CMD config diff

echo $SEPARATOR
echo "Replacing loopback ip with actual hostname..."
$KUBECTL_EXEC -- $GADMIN_CMD config get System.HostList
$KUBECTL_EXEC -- $GADMIN_CMD config set System.HostList "[{\"Hostname\":\"${TARGET_FQDN}\",\"ID\":\"m1\",\"Region\":\"\"}]"
$KUBECTL_EXEC -- $GADMIN_CMD config diff

echo $SEPARATOR
echo "Applying config..."
$KUBECTL_EXEC -- $GADMIN_CMD config apply -y
sleep 30

echo $SEPARATOR
echo "--- Waiting for GSQL service to be Online ---"
MAX_ATTEMPTS=30
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    # Check status and look for the word 'Online'
    STATUS=$($KUBECTL_EXEC -- $GADMIN_CMD status gsql | grep "GSQL" || echo "Down")
    
    if [[ $STATUS == *"Online"* ]]; then
        echo "GSQL is Online! Proceeding with schema creation..."
        break
    fi
    
    echo "GSQL status: $STATUS. Waiting 15s... (Attempt $i/$MAX_ATTEMPTS)"
    sleep 15
    
    if [ $i -eq $MAX_ATTEMPTS ]; then
        echo "Error: GSQL failed to come online in time."
        $KUBECTL_EXEC -- $GADMIN_CMD log admin # Dump logs if it fails
        exit 1
    fi
done

echo $SEPARATOR
echo "Adding dummy vertex and graph.."
echo $gsql_cmd
$KUBECTL_EXEC -i -- $GSQL_CMD -p tigergraph "CREATE VERTEX dummyvertex(PRIMARY_ID id INT)"
$KUBECTL_EXEC -i -- $GSQL_CMD -p tigergraph "CREATE GRAPH dummygraph(dummyvertex)"

echo $SEPARATOR
echo "Applying config and restarting all services..."
$KUBECTL_EXEC -- $GADMIN_CMD config apply -y
$KUBECTL_EXEC -- $GADMIN_CMD restart all -y
