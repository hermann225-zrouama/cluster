#!/bin/bash

set -e

echo "=== Installation des applications personnalisées ==="

cd /home/frappe/frappe-bench

# Liste des applications personnalisées à installer
CUSTOM_APPS=(
    "--branch version-14 https://github.com/frappe/hrms.git"  # Avec branche
    "https://github.com/frappe/payments.git"                   # Sans branche
    "https://github.com/aakvatech/transport.git"               # Sans branche
)

# Installer chaque application personnalisée
for entry in "${CUSTOM_APPS[@]}"; do
    if [ -n "$entry" ] && [[ $entry != \#* ]]; then
        echo "Traitement : $entry"

        # Séparer les arguments (si présence de --branch)
        read -r first second <<< "$entry"

        if [[ "$first" == --branch ]]; then
            branch="$second"
            repo_url=$(echo "$entry" | awk '{print $3}')
        else
            branch=""
            repo_url="$first"
        fi

        app_name=$(basename "$repo_url" .git)
        echo "Installation de l'application $app_name depuis: $repo_url"

        if [ ! -d "apps/$app_name" ]; then
            if [ -n "$branch" ]; then
                bench get-app "$branch" "$repo_url"
            else
                bench get-app "$repo_url"
            fi

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

# Construction des assets si des apps ont été ajoutées
if [ ${#CUSTOM_APPS[@]} -gt 0 ]; then
    echo "Construction des assets..."
    bench build --app erpnext
    echo "✓ Assets construits"
fi

echo "=== Installation terminée ==="
