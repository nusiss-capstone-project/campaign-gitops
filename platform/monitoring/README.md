# Demo monitoring stack

Lightweight Prometheus + Grafana + OTel Collector for campaign-dev demos.

| Component | ArgoCD Application | Notes |
|-----------|-------------------|--------|
| kube-prometheus-stack `72.9.1` | `kube-prometheus-stack` | Prometheus, Grafana, Operator, kube-state-metrics (no default dashboards/rules — keeps ArgoCD sync light) |
| OTel Collector (spanmetrics) | `otel-collector` | OTLP `:4317/4318`, metrics `:8889` |
| Grafana IngressRoute | `monitoring-routes` | `https://grafana.campaignhub.best` |

Namespace: `monitoring`.

## Sync order

1. Sync **`kube-prometheus-stack`** first (installs Prometheus Operator CRDs).
2. Sync **`otel-collector`** (includes `ServiceMonitor`).
3. Sync **`monitoring-routes`** (Grafana Traefik route).
4. Roll microservices so they pick up `charts/go-service` OTEL env defaults.

## Grafana

- URL: `https://grafana.campaignhub.best` (DNS / Cloudflare → cluster Traefik)
- User / password: `admin` / `campaign-demo` (demo only; in `platform/kube-prometheus-stack/values.yaml`)

Port-forward fallback:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

## Verify Prometheus targets

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# open http://localhost:9090/targets
# expect: serviceMonitor/monitoring/otel-collector-spanmetrics/... = UP
```

## Verify OTel spanmetrics

```bash
# Collector exposes Prometheus metrics from spanmetrics connector
kubectl -n monitoring port-forward svc/otel-collector 8889:8889
curl -s localhost:8889/metrics | head

# After traffic to any Go service with OTEL enabled:
# Prometheus UI → query e.g. traces_span_metrics_calls_total or otelcol_*
```

## Microservice OTEL defaults (`charts/go-service`)

Injected when `otel.enabled: true` (default):

| Env | Default |
|-----|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://otel-collector.monitoring.svc.cluster.local:4318` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
| `OTEL_EXPORTER_OTLP_HEADERS` | `x-campaign-otel=dev` |
| `OTEL_SERVICE_NAME` | `serviceName` from values |

Override per service in `apps/<service>/values.yaml` under `otel:` or `extraEnv`.

**Vault:** not required for these demo OTEL vars (non-secret). Optional: still set `APP_ENV=dev` in each service Vault path so logs show `env=dev`.

## ServiceMonitor (confirmed from this repo)

| Field | Value |
|-------|--------|
| namespace | `monitoring` |
| Service | `otel-collector` |
| port name | `metrics` → `8889` |
| path | `/metrics` |
| Pod/Service labels | `app.kubernetes.io/name: otel-collector` |
| Prometheus select label | `release: kube-prometheus-stack` |
