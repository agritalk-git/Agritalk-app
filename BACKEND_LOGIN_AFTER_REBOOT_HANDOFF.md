# Backend login failure after server reboot

## Context

After a server network-architecture change, a teammate said some features were not working and the server needed a reboot ("因為昨天的server網路架構調整，目前有些功能無法正常運作。需要重開機"). The server was rebooted with `sudo reboot`. Afterward, users could no longer log in to the app.

PostgreSQL's Docker container was found stopped and was started. These app-related containers were also found stopped with exit code 128:

- `ricetalk_api_server_1` — publishes host port `9987` to container port `5000`
- `ricetalk_nw_1_1`
- `ricetalk_nw_2_1`
- `ricetalk_nw_3_1`
- `ricetalk_nw_4_1`

The containers have since been brought back up, but login still fails. It is not yet known whether the containers remain healthy, whether the API can reach PostgreSQL, or whether the network-architecture change altered routing, DNS, firewall rules, or proxy configuration.

## Request

On the server, diagnose why app login fails after the reboot and report the evidence and likely root cause. Treat "restart all programs" as ambiguous: identify the actual services and dependencies before restarting anything else.

## Investigation

1. Identify the deployment method and relevant Compose project/files. Do not assume every stopped container is part of this app.
2. Record current container status, restart counts, health checks, ports, and network attachments. Confirm whether the API and all required dependencies are still running.
3. Review recent logs for the API, PostgreSQL, the `ricetalk_nw_*` containers, and any reverse proxy/load balancer. Look for startup failures, database connection errors, DNS/network errors, and authentication errors. Use a time window around the reboot.
4. Verify PostgreSQL is ready and that the API can resolve and connect to the configured database over the intended Docker network. Do not print or expose credentials.
5. Test the API locally on the server using its documented health/readiness endpoint and the actual login endpoint or a safe test account. The host mapping is `9987 -> 5000`; do not assume `/` is a health endpoint.
6. If the API works locally, inspect the path from the client through the proxy/load balancer and check DNS, firewall rules, routes, and TLS as relevant to the recent network change.
7. Check whether containers have an appropriate restart policy and whether their Compose configuration expects automatic recovery after host reboot. Do not change policies until the intended operational behavior is clear.
8. Compare the current network/proxy configuration with the change made yesterday if its change record or owner is available.

Useful initial commands:

```bash
sudo docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
sudo docker compose ls
sudo docker logs --since 30m --tail 200 ricetalk_api_server_1
sudo docker logs --since 30m --tail 200 <postgres-container-name>
sudo docker inspect -f '{{.Name}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}} restart={{.RestartCount}} networks={{range $name, $value := .NetworkSettings.Networks}}{{$name}} {{end}}' ricetalk_api_server_1
sudo ss -lntp
```

Run Compose commands from the correct project directory. Avoid dumping full environment variables or unredacted Compose configuration because they can contain credentials.

## Safety and report back

- Do not reboot the server again or restart every container indiscriminately.
- Do not delete containers, volumes, or data; do not run database migrations or alter firewall/network settings without confirming the cause and getting approval.
- Preserve relevant logs and report exact timestamps, commands/results, and any error messages. Redact passwords, tokens, connection strings, and personal data.
- If a restart is necessary, state which service and why, then verify its health and the login flow afterward.
- If the evidence is inconclusive, report what was checked and what access or information is needed next rather than guessing.
