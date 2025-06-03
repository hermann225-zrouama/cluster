# clickhouse
helm -n clickhouse install clickhouse oci://registry-1.docker.io/bitnamicharts/clickhouse
echo "Username: default"
echo "Password: $(kubectl get secret --namespace clickhouse clickhouse -o jsonpath="{.data.admin-password}" | base64 -d)"
wXr5SXFpXM