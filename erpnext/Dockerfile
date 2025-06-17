# Dockerfile pour zetsu225/erpnext-image:latest
FROM frappe/erpnext:v15.0.0

# Métadonnées
LABEL maintainer="zetsu225"
LABEL description="ERPNext Custom Image with Additional Modules"
LABEL version="1.0.0"

# Variables d'environnement
ENV FRAPPE_BRANCH=version-15
ENV ERPNEXT_BRANCH=version-15

# Passer en mode root pour les installations
USER root

# Installer les dépendances additionnelles
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    python3-dev \
    python3-pip \
    nodejs \
    npm \
    # Ajoutez vos dépendances spécifiques ici
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Créer le répertoire pour les applications personnalisées
RUN mkdir -p /home/frappe/frappe-bench/apps/custom

# Copier les scripts d'installation personnalisés
COPY install-apps.sh /home/frappe/install-apps.sh
RUN chmod +x /home/frappe/install-apps.sh

# Si vous avez des applications personnalisées à inclure directement
# COPY custom-apps/ /home/frappe/frappe-bench/apps/custom/

# Changer de propriétaire
RUN chown -R frappe:frappe /home/frappe/frappe-bench/apps/custom
RUN chown frappe:frappe /home/frappe/install-apps.sh

# Revenir à l'utilisateur frappe
USER frappe

# Définir le répertoire de travail
WORKDIR /home/frappe/frappe-bench

# Installer les applications personnalisées si présentes
RUN /home/frappe/install-apps.sh

# Point d'entrée par défaut (hérite de l'image parent)