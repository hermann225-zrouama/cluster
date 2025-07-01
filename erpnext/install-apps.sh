#!/bin/bash
set -e

echo "=== Installation des applications personnalisées ==="
cd /home/frappe/frappe-bench

# Configuration des applications avec leurs branches spécifiques
# Format: "URL|BRANCHE" ou juste "URL" pour la branche par défaut
declare -A CUSTOM_APPS=(
    ["https://github.com/frappe/hrms.git"]="version-14"
    ["https://github.com/frappe/payments.git"]=""  # Branche par défaut
    ["https://github.com/aakvatech/transport.git"]=""  # Branche par défaut
    # Ajoutez d'autres applications selon vos besoins
    # ["https://github.com/exemple/app.git"]="develop"  # Exemple avec branche spécifique
)

# Installer chaque application personnalisée
for app_url in "${!CUSTOM_APPS[@]}"; do
    if [ ! -z "$app_url" ]; then
        branch="${CUSTOM_APPS[$app_url]}"
        app_name=$(basename "$app_url" .git)
        
        echo "Installation de l'application depuis: $app_url"
        
        # Cloner l'application
        if [ ! -d "apps/$app_name" ]; then
            if [ ! -z "$branch" ]; then
                echo "Installation de $app_name avec la branche: $branch"
                bench get-app --branch "$branch" "$app_url"
            else
                echo "Installation de $app_name avec la branche par défaut"
                bench get-app "$app_url"
            fi
            
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