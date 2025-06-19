# 1- Install Helm
helm install frappe-bench -n erp-test -f values.yaml frappe/erpnext

# 2- Update ERPNext with Helm
helm upgrade frappe-bench frappe/erpnext -f values.yaml -n erp-test
kubectl -n erp-test exec -it erpnext-gunicorn-xxxx -- bash
# execute bench migrate commands in the container
bench --site $SITE_NAME migrate --skip-failing

# 3- Uninstall ERPNext with Helm
 