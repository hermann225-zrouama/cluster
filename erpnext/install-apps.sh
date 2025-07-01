#!/bin/bash

set -e

echo "=== Installation des applications personnalisées ==="

cd /home/frappe/frappe-bench

# Liste des applications personnalisées à installer
# Ajoutez vos applications ici
CUSTOM_APPS=(
    "https://github.com/frappe/hrms.git"  # Déjà inclus dans votre config
    "https://github.com/frappe/payments.git"  # Déjà inclus dans votre config
    "https://github.com/aakvatech/transport.git" 
    # Ajoutez d'autres applications selon vos besoins
)

# Installer chaque application personnalisée
for app_url in "${CUSTOM_APPS[@]}"; do
    if [ ! -z "$app_url" ] && [[ $app_url != \#* ]]; then
        echo "Installation de l'application depuis: $app_url"
        app_name=$(basename "$app_url" .git)
        
        # Cloner l'application
        if [ ! -d "apps/$app_name" ]; then
            bench get-app --branch version-14 "$app_url"
            
            # Installer les dépendances si requirements.txt existe
            if [ -f "apps/$app_name/requirements.txt" ]; then
                echo "Installation des dépendances pour $app_name"
                pip3 install -r "apps/$app_name/requirements.txt"
            fi
            
            echo "✓ Application $app_name installée"
        else
            echo "✓ Application $app_name déjà présente"
        fi
    fi
done

# Construire les assets si des applications ont été ajoutées
if [ ${#CUSTOM_APPS[@]} -gt 0 ]; then
    echo "Construction des assets..."
    bench build --app erpnext
    echo "✓ Assets construits"
fi

echo "=== Installation terminée ==="