# 1- Install Helm
helm install frappe-bench -n $NAMESPACE -f values.yaml frappe/erpnext

# 2- Update ERPNext with Helm
helm upgrade frappe-bench frappe/erpnext -f values.yaml -n $NAMESPACE
kubectl -n $NAMESPACE exec -it erpnext-gunicorn-xxxx -- bash
# execute bench migrate commands in the container
bench --site $SITE_NAME migrate --skip-failing

# 3- Uninstall ERPNext with Helm
helm uninstall frappe-bench -n $NAMESPACE