FROM --platform=linux/amd64 frappe/erpnext:v14.34.0

# Métadonnées
LABEL maintainer="zetsu225"
LABEL description="TEST VERSION 14"
LABEL version="1.0.2"

# Variables d'environnement
ENV FRAPPE_BRANCH=version-14
ENV ERPNEXT_BRANCH=version-14

# Passer en mode root pour les installations système
USER root

# Installer les dépendances additionnelles
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    python3-dev \
    python3-pip \
    build-essential \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Installer Node 20 et forcer tous les chemins à l'utiliser
RUN npm install -g n@latest && \
    n 20 && \
    rm -f /usr/bin/node /usr/bin/npm /usr/bin/npx || true && \
    ln -sf /usr/local/n/versions/node/20/bin/node /usr/bin/node && \
    ln -sf /usr/local/n/versions/node/20/bin/npm /usr/bin/npm && \
    ln -sf /usr/local/n/versions/node/20/bin/npx /usr/bin/npx && \
    npm install -g yarn@1.22.19

# S'assurer que le PATH est bon pour tous les users
ENV PATH="/usr/local/n/versions/node/20/bin:$PATH"



# Mettre à jour pip et setuptools au niveau système
RUN pip3 install --upgrade pip setuptools wheel

# Installer @rollup/plugin-json globalement pour résoudre l'erreur
RUN npm install -g @rollup/plugin-json

# Créer un fichier de configuration temporaire pour éviter les erreurs de build
RUN mkdir -p /home/frappe/frappe-bench/sites && \
    echo '{"socketio_port": 9000}' > /home/frappe/frappe-bench/sites/common_site_config.json

# Changer de propriétaire
RUN chown -R frappe:frappe /home/frappe/frappe-bench/

# Revenir à l'utilisateur frappe pour les installations Python
USER frappe

# Définir le répertoire de travail
WORKDIR /home/frappe/frappe-bench

# Installer python-telegram-bot dans le bon environnement Python
RUN if [ -d "env" ]; then \
        echo "Installation dans l'environnement virtuel Frappe..."; \
        ./env/bin/pip install --upgrade pip; \
        ./env/bin/pip install python-telegram-bot; \
    else \
        echo "Installation avec pip utilisateur..."; \
        pip3 install --user python-telegram-bot; \
    fi



# Copier les scripts d'installation personnalisés
COPY install-apps.sh /home/frappe/install-apps.sh
USER root
RUN chown frappe:frappe /home/frappe/install-apps.sh && chmod +x /home/frappe/install-apps.sh
USER frappe

# Installer les applications personnalisées
RUN /home/frappe/install-apps.sh

# Point d'entrée par défaut (hérite de l'image parent)