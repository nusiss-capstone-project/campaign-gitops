# campaign-demo1 environment (`demo` branch)

Parallel environment for demo / prod-like traffic. Shares cluster infra with `campaign-dev`.

| Item | Value |
|------|--------|
| Git branch | `demo` |
| Namespace | `campaign-demo1` |
| Public host | `demo1.campaignhub.best` |
| ArgoCD apps | `demo-*` (synced by a **separate** App-of-Apps root) |
| Vault | `campaign-center/demo1/<service>` |
| Kafka topic prefix env | `KAFKA_TOPIC_PREFIX=demo.` (apps must prepend) |
| Kafka group / client ids | `demo-<service>` |
| Auth forward | `identity-mservice.campaign-dev` (shared) |
| HTTP `/identity-ms` | Routed to `campaign-dev` identity (Singpass/Clerk stay on `campaignhub.best`) |
| OTEL | `APP_ENV=demo`, `deployment.environment=demo1` |
| Logs | LoongCollector pipeline `campaign-demo1-stdout` → same SLS logstore, filter by namespace |

Not managed on this branch: LoongCollector operator, mockpass, Grafana Alloy.
