#!/bin/bash

# Script de déploiement automatisé ERPNext avec apps
# Usage: ./deploy-erpnext.sh [install|upgrade|sync-apps]

set -e

NAMESPACE="erp-dev"
RELEASE_NAME="frappe-bench"
CHART_PATH="frappe/erpnext"
VALUES_FILE="values.yaml"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour installer/upgrader ERPNext
deploy_erpnext() {
    local action=$1
    
    log_info "Début du déploiement ERPNext ($action)..."
    
    if [ "$action" = "install" ]; then
        log_info "Installation d'ERPNext avec Helm..."
        helm install $RELEASE_NAME $CHART_PATH \
            -f $VALUES_FILE \
            --namespace $NAMESPACE \
            --create-namespace \
            --wait \
            --timeout 30m
    else
        log_info "Mise à jour d'ERPNext avec Helm..."
        helm upgrade $RELEASE_NAME $CHART_PATH \
            -f $VALUES_FILE \
            --namespace $NAMESPACE \
            --wait \
            --timeout 30m
    fi
    
    log_info "Attente de la stabilisation des pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE --timeout=600s
}

# Fonction pour synchroniser les apps sur tous les pods
sync_apps() {
    log_info "Synchronisation des apps sur tous les pods..."
    
    # Liste des apps à installer
    APPS=("hrms" "payments" "ecommerce_integrations")
    
    # Types de pods qui ont besoin des apps
    POD_LABELS=(
        "app.kubernetes.io/component=gunicorn"
        "app.kubernetes.io/component=worker-default"
        "app.kubernetes.io/component=worker-short"
        "app.kubernetes.io/component=worker-long"
        "app.kubernetes.io/component=scheduler"
    )
    
    for label in "${POD_LABELS[@]}"; do
        log_info "Traitement des pods avec label: $label"
        
        pods=$(kubectl get pods -l "$label" -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE -o name)
        
        for pod in $pods; do
            pod_name=$(basename $pod)
            log_info "Synchronisation des apps sur le pod: $pod_name"
            
            # Vérification que le pod est prêt
            if kubectl wait --for=condition=ready $pod -n $NAMESPACE --timeout=60s; then
                # Installation des apps
                for app in "${APPS[@]}"; do
                    log_info "Vérification de l'app $app sur $pod_name..."
                    
                    # Vérifier si l'app existe déjà
                    if ! kubectl exec $pod -n $NAMESPACE -- ls /home/frappe/frappe-bench/apps/$app >/dev/null 2>&1; then
                        log_info "Installation de $app sur $pod_name..."
                        kubectl exec $pod -n $NAMESPACE -- bench get-app $app || log_warn "Échec de l'installation de $app sur $pod_name"
                    else
                        log_info "$app déjà présente sur $pod_name"
                    fi
                done
                
                # Installation des apps sur le site
                log_info "Installation des apps sur le site pour $pod_name..."
                for app in "${APPS[@]}"; do
                    kubectl exec $pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com install-app $app 2>/dev/null || log_warn "$app déjà installée sur le site"
                done
                
            else
                log_error "Pod $pod_name n'est pas prêt, passage au suivant"
            fi
        done
    done
    
    # Migration finale
    log_info "Exécution de la migration finale..."
    gunicorn_pod=$(kubectl get pods -l "app.kubernetes.io/component=gunicorn" -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE -o name | head -1)
    if [ -n "$gunicorn_pod" ]; then
        kubectl exec $gunicorn_pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com migrate || log_warn "Migration échouée"
    fi
}

# Fonction pour vérifier l'état des apps
check_apps_status() {
    log_info "Vérification de l'état des apps..."
    
    gunicorn_pod=$(kubectl get pods -l "app.kubernetes.io/component=gunicorn" -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE -o name | head -1)
    
    if [ -n "$gunicorn_pod" ]; then
        log_info "Apps installées sur le site:"
        kubectl exec $gunicorn_pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com list-apps
        
        log_info "État des services:"
        kubectl exec $gunicorn_pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com doctor || true
    else
        log_error "Aucun pod gunicorn trouvé"
    fi
}

# Fonction pour redémarrer tous les workers
restart_workers() {
    log_info "Redémarrage de tous les workers..."
    
    kubectl rollout restart deployment/$RELEASE_NAME-gunicorn -n $NAMESPACE
    kubectl rollout restart deployment/$RELEASE_NAME-worker-default -n $NAMESPACE
    kubectl rollout restart deployment/$RELEASE_NAME-worker-short -n $NAMESPACE
    kubectl rollout restart deployment/$RELEASE_NAME-worker-long -n $NAMESPACE
    kubectl rollout restart deployment/$RELEASE_NAME-scheduler -n $NAMESPACE
    
    log_info "Attente de la stabilisation des redémarrages..."
    kubectl rollout status deployment/$RELEASE_NAME-gunicorn -n $NAMESPACE
    kubectl rollout status deployment/$RELEASE_NAME-worker-default -n $NAMESPACE
    kubectl rollout status deployment/$RELEASE_NAME-worker-short -n $NAMESPACE
    kubectl rollout status deployment/$RELEASE_NAME-worker-long -n $NAMESPACE
    kubectl rollout status deployment/$RELEASE_NAME-scheduler -n $NAMESPACE
}

# Fonction principale
main() {
    case "${1:-}" in
        "install")
            deploy_erpnext "install"
            sleep 60  # Attendre que tout soit stable
            sync_apps
            check_apps_status
            ;;
        "upgrade")
            deploy_erpnext "upgrade"
            sleep 30
            sync_apps
            restart_workers
            check_apps_status
            ;;
        "sync-apps")
            sync_apps
            check_apps_status
            ;;
        "restart")
            restart_workers
            ;;
        "status")
            check_apps_status
            ;;
        *)
            echo "Usage: $0 {install|upgrade|sync-apps|restart|status}"
            echo ""
            echo "Commands:"
            echo "  install    - Installation complète d'ERPNext avec apps"
            echo "  upgrade    - Mise à jour d'ERPNext avec synchronisation des apps"
            echo "  sync-apps  - Synchronise les apps sur tous les pods existants"
            echo "  restart    - Redémarre tous les workers"
            echo "  status     - Vérifie l'état des apps installées"
            exit 1
            ;;
    esac
    
    log_info "Opération terminée avec succès!"
}

# Vérifications préalables
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl n'est pas installé"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    log_error "helm n'est pas installé"
    exit 1
fi

if [ ! -f "$VALUES_FILE" ]; then
    log_error "Fichier values.yaml non trouvé"
    exit 1
fi

main "$@"