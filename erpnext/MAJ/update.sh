# 1. Backup avant mise à jour
kubectl create job --from=cronjob/erpnext-backup erpnext-backup-manual -n erp-test

# 2. Mise à jour avec nouveau tag
helm upgrade erpnext frappe/erpnext -n erp-test -f update-values.yaml

# 3. Vérification de la migration
kubectl logs -f job/erpnext-migrate -n erp-test

# 4. En cas de problème, rollback
helm rollback erpnext -n erp-test