# LoongCollector → Alibaba Cloud SLS

GitOps manifests for collecting **`campaign-dev`** container stdout/stderr into SLS.

| Item | Value |
|------|--------|
| Project | `log-service-1558398056044027-ap-southeast-1` |
| Logstore | `k8s-campaign-center-stdout-dev` |
| Region / net | `ap-southeast-1` / `Intranet` |
| Vault | `campaign-center/dev/loongcollector` (`ACCESS_KEY_ID`, `ACCESS_KEY_SECRET`, `ALI_UID`) |
| Chart | `charts/loongcollector` (upstream 3.2.6, patched for `existingSecret`) |

## Apps

1. `argocd/applications/loongcollector.yaml` — Helm agent (DaemonSet + operator + CRDs) in `kube-system`
2. `argocd/applications/loongcollector-config.yaml` — ExternalSecret + `ClusterAliyunPipelineConfig`

Sync **loongcollector** first (CRDs), then **loongcollector-config**. Automated sync is off until the first install is verified.

## After push / ArgoCD sync

1. Confirm ExternalSecret created `loongcollector-sls-credentials` in `kube-system`
2. Confirm `loongcollector-ds` pods are Ready
3. Confirm SLS machine group for `campaign-k3s-dev` is online
4. Hit any `campaign-dev` API and query Logstore: `__tag__:__namespace__: campaign-dev`
