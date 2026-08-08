# campaign-center-gitops

GitOps repository for **Kubernetes application deployment state** of the Campaign Center platform.

This repo defines *what* runs on the cluster — container images, replica counts, configuration, ingress routes, and secret references. It does **not** provision cloud infrastructure.

## What belongs here vs the IaC repo

| This repo (GitOps) | IaC repo |
|---|---|
| Helm charts and per-service `values.yaml` | ECS / k3s cluster provisioning |
| ArgoCD Application manifests | ArgoCD installation and bootstrap |
| Application ConfigMaps (`config.yml`) | Vault, External Secrets Operator |
| ExternalSecret definitions (Vault path refs) | Traefik installation, namespaces, ACR pull secrets |
| Shared Traefik IngressRoute (`traefik/`) | ClusterSecretStore / SecretStore setup |

Sensitive values are **never** committed here. Secrets are sourced from HashiCorp Vault via the External Secrets Operator, which is installed and configured in the IaC repository.

## Repository layout

```
campaign-center-gitops/
├── charts/go-service/          # Reusable Helm chart for all Go microservices
├── apps/<service-name>/        # Per-service deployment values (one file per branch)
│   └── values.yaml
├── platform/                   # Platform add-ons (LoongCollector, monitoring, OTel)
├── traefik/                    # Shared Traefik IngressRoute
└── argocd/applications/        # ArgoCD Application manifests
```

Demo monitoring (Prometheus / Grafana / OTel) lives under `platform/` — see [`platform/monitoring/README.md`](platform/monitoring/README.md).

## Branch-based environments

Environments are separated by Git branch — not by multiple values files:

| Branch | Environment |
|---|---|
| `dev` | Development |
| `staging` | Staging |
| `main` | Production |

Each branch contains its own `apps/<service-name>/values.yaml` with environment-specific image tags, Vault paths, and configuration. HTTP routing is maintained in `traefik/ingressroute.yaml` per branch. Do **not** create `values-dev.yaml`, `values-staging.yaml`, or `values-prod.yaml`.

ArgoCD Applications point to the appropriate branch via `targetRevision`.

## How to add a new Go microservice

1. **Create application values**

   ```bash
   mkdir -p apps/<service-name>
   cp apps/task-mservice/values.yaml apps/<service-name>/values.yaml
   ```

   Update `serviceName`, image repository/tag, `configFile.content`, Vault paths, and secret names.

2. **Add a Traefik route**

   Add a `PathPrefix` rule in `traefik/ingressroute.yaml` for the shared API host (for example `/task-ms`).

3. **Store secrets in Vault**

   Add secrets to Vault at the path referenced in `externalSecret.remoteRef.key` (for example, `campaign-center/dev/<service-name>`).

4. **Create an ArgoCD Application**

   ```bash
   cp argocd/applications/task-mservice.yaml argocd/applications/<service-name>.yaml
   ```

   Update the application name, destination namespace, value file path, and `targetRevision` for the target environment.

5. **Commit and push** — the root ArgoCD Application loads manifests from `argocd/applications/` automatically.

The `go-service` chart is generic — no service-specific logic lives inside the chart. Future services such as `campaign-api`, `reward-service`, `user-service`, and `payment-service` only need a new `apps/<service-name>/values.yaml` and ArgoCD Application.

## How to update image tags

Edit the image tag in the environment branch's values file:

```yaml
# apps/<service-name>/values.yaml
image:
  repository: registry.cn-singapore.aliyuncs.com/campaign-center/<service-name>
  tag: dev-latest   # change to the new tag
```

Commit and push to the target branch. ArgoCD detects the change and syncs automatically when automated sync is enabled.

## How ArgoCD syncs changes

Each Application in `argocd/applications/` tells ArgoCD to:

1. Watch a Git branch (`targetRevision`)
2. Render the `charts/go-service` Helm chart
3. Merge in the service-specific values file from `apps/<service-name>/values.yaml`
4. Apply the resulting manifests to the destination namespace

Automated sync is enabled with **prune** and **selfHeal**, so drift from the desired Git state is corrected automatically. `CreateNamespace=true` ensures the destination namespace is created if it does not exist.

## How config.yml is mounted

All Go services use a unified `config.yml` format. The chart:

1. Renders `configFile.content` from values into a ConfigMap
2. Mounts the file into the container at `configFile.mountPath` (default: `/app/config.yml`)

Example values:

```yaml
configFile:
  enabled: true
  name: config.yml
  mountPath: /app/config.yml
  content:
    http:
      host: "0.0.0.0"
      port: 8080
    # ... arbitrary YAML
```

Non-sensitive configuration belongs in Git. Never put secrets in `configFile.content`.

## How Vault secrets are referenced

Secrets are pulled from Vault through External Secrets Operator. Enable per service with:

```yaml
externalSecret:
  enabled: true
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-backend
  targetSecretName: <service-name>-secret
  refreshInterval: 1h
  remoteRef:
    key: campaign-center/dev/<service-name>

envFromSecret:
  enabled: true
  secretName: <service-name>-secret
```

All keys under the Vault path are synced into the Kubernetes Secret via `dataFrom.extract`. The Secret is injected into the Deployment via `envFrom.secretRef`.

## Deploy task-mservice first

Prerequisites (managed in the IaC repo):

- k3s cluster running
- ArgoCD installed and connected to this repository
- External Secrets Operator with a `ClusterSecretStore` named `vault-backend`
- Vault secret at `campaign-center/dev/task-mservice` (all keys synced automatically)
- Traefik IngressRoute via `traefik-routes` ArgoCD Application
- `acr-secret` image pull secret in the `campaign-dev` namespace

Steps:

1. Push this repository to GitHub on the `dev` branch.

2. Ensure `apps/task-mservice/values.yaml` and `traefik/ingressroute.yaml` are present.

3. Verify sync in the ArgoCD UI or CLI:

   ```bash
   argocd app get task-mservice
   argocd app get traefik-routes
   kubectl get pods -n campaign-dev -l app.kubernetes.io/name=task-mservice
   ```

4. Confirm routing once DNS points `api.dev.example.com` at the cluster (`/task-ms/v1/ping`).

## Local validation

Render manifests locally before pushing:

```bash
helm template task-mservice charts/go-service \
  -f apps/task-mservice/values.yaml
```

Lint the chart:

```bash
helm lint charts/go-service -f apps/task-mservice/values.yaml
```
