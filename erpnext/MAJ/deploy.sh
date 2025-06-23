# Déploiement de la version Green
helm install erpnext-green frappe/erpnext -n erp-test -f blue-green-values.yaml

# Test de la version Green
kubectl port-forward svc/erpnext-green 8001:8001 -n erp-test

# Basculement du trafic (modification de l'ingress)
# Suppression de l'ancienne version
helm uninstall erpnext -n erp-test