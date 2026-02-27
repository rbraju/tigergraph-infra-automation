## tigergraph-infra-automation

Automation to deploy and initialize a TigerGraph instance on Kubernetes, driven by a Jenkins pipeline.

### High-level flow

- **Jenkins** runs the `Jenkinsfile` pipeline.
- The pipeline uses `kubectl` and the `k8s/tigergraph-setup.yml` manifest to create a TigerGraph StatefulSet and service.
- Once the pod is running, helper scripts in `scripts/`:
  - set up SSH access into the TigerGraph pod
  - apply the TigerGraph license
  - configure the host list
  - wait for GSQL to come online and create a simple test graph.

### Files and directories

- **`Jenkinsfile`**: Declarative Jenkins pipeline that:
  - Ensures `kubectl` is available in the build agent.
  - Uses a Kubernetes kubeconfig credential (`tg-infra-kubeconfig`) to:
    - delete and recreate the `tigergraph` namespace,
    - apply the `k8s/tigergraph-setup.yml` manifest,
    - wait for the `tg-0` pod to become Ready,
    - run the helper scripts under `scripts/` for SSH setup and TigerGraph initialization.
  - Reads the TigerGraph license key from the Jenkins credential `tg-license-key`.

- **`k8s/tigergraph-setup.yml`**: Kubernetes manifest that:
  - Creates a `Service` named `tg-svc` in the `tigergraph` namespace exposing:
    - port **9090** (REST),
    - port **14240** (GUI).
  - Defines a `StatefulSet` named `tg` with:
    - 1 replica running the `tigergraph/tigergraph:4.2.2` image,
    - label `app: tigergraph`,
    - environment variable `SSH_PASSWORD` used for SSH access,
    - a `PersistentVolumeClaim` template `tigergraph-data` requesting 10Gi.

- **`scripts/setup_ssh.sh`**: Bash script that:
  - Generates a new RSA SSH key pair in the Jenkins workspace (`./id_rsa`, `./id_rsa.pub`).
  - Injects the public and private keys into the `tg-0` pod (namespace `${TG_NAMESPACE}`) using `./kubectl --kubeconfig=$KUBECONFIG_FILE`.
  - Creates and configures `~/.ssh` inside the pod:
    - writes `authorized_keys` and `id_rsa`,
    - disables strict host key checking for convenience in automation,
    - ensures ownership is `tigergraph:tigergraph`.
  - Allows passwordless SSH between TigerGraph processes for cluster-style operations.

- **`scripts/init_tigergraph.sh`**: Bash script that:
  - Uses `./kubectl --kubeconfig=$KUBECONFIG_FILE exec` to run `gadmin` and `gsql` commands inside the `tg-0` pod.
  - Waits for the TigerGraph controller (`gadmin`) to respond.
  - Applies the TigerGraph license using the `TG_LICENSE_KEY` environment variable (injected from Jenkins credentials).
  - Updates the `System.HostList` configuration to use the pod’s fully qualified domain name (`tg-0.tg-svc.${TG_NAMESPACE}.svc.cluster.local`).
  - Applies configuration changes and waits for services to stabilize.
  - Waits for the GSQL service to reach the `Online` state, dumping logs and exiting if it times out.
  - Creates a simple test schema:
    - vertex `dummyvertex`,
    - graph `dummygraph(dummyvertex)`.
  - Re-applies config and restarts all services.

- **`license.txt`**: Example TigerGraph license token used for development/testing.
  - In a real setup, this should **not** be committed to source control.
  - Prefer storing licenses as secrets or Jenkins credentials (`tg-license-key`).

- **`.gitignore`**: Git ignore rules for this repository.

### Credentials & environment variables

- **`KUBE_CREDENTIAL_ID` / `tg-infra-kubeconfig`**: Jenkins file credential containing a kubeconfig for the target Kubernetes cluster.
- **`TG_NAMESPACE`**: Kubernetes namespace where TigerGraph resources are created (default: `tigergraph`).
- **`TG_LICENSE_KEY`**: Jenkins credential holding the TigerGraph license string, exposed to the pipeline as an environment variable.
