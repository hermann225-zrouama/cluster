FROM python:3.10-slim

# Pré-requis système
RUN apt-get update && apt-get install -y \
    git curl cron supervisor nginx \
    mariadb-client default-libmysqlclient-dev \
    build-essential libffi-dev python3-dev \
    libssl-dev wkhtmltopdf nodejs npm redis \
    && apt-get clean

# Installer yarn et bench
RUN npm install -g yarn \
    && pip install frappe-bench

# Créer dossier bench
WORKDIR /opt/bench

# Initialiser bench
RUN bench init erp-bench --frappe-branch version-14

WORKDIR /opt/bench/erp-bench

# Créer site
RUN bench new-site erpnext.localhost --no-mariadb-socket --admin-password admin --mariadb-root-password root

# Installer ERPNext
RUN bench get-app --branch version-14 erpnext https://github.com/frappe/erpnext \
    && bench --site erpnext.localhost install-app erpnext

# Exposer les ports
EXPOSE 8000

# Commande pour lancer le bench
CMD ["bench", "start"]
