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
    
    log_info "Attente de la stabilisation des pods ERPNext..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=$RELEASE_NAME -l app.kubernetes.io/name=erpnext -n $NAMESPACE --timeout=600s
}

# Fonction pour obtenir les pods ERPNext uniquement (excluant MariaDB et Redis)
get_erpnext_pods() {
    local component=$1
    kubectl get pods -n $NAMESPACE -o name \
        | grep "$component" || echo ""
}


# Fonction pour synchroniser les apps sur tous les pods ERPNext
sync_apps() {
    log_info "Synchronisation des apps sur tous les pods ERPNext..."
    
    # Liste des apps à installer
    APPS=("hrms")
    
    # Types de composants ERPNext qui ont besoin des apps (excluant mariadb et redis)
    COMPONENTS=(
        "erpnext-gunicorn"
        "erpnext-worker-d" 
        "erpnext-worker-s"
        "erpnext-worker-l"
        "erpnext-socketio"
    )
    
    for component in "${COMPONENTS[@]}"; do
        log_info "Traitement des pods du composant: $component"
        
        pods=$(get_erpnext_pods "$component")
        
        if [ -z "$pods" ]; then
            log_warn "Aucun pod trouvé pour le composant $component, essai avec des labels alternatifs..."
            # Fallback pour les noms de pods qui pourraient être différents
            pods=$(kubectl get pods -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE -o name | grep -E "(gunicorn|worker|scheduler|socketio)" | grep -v -E "(mariadb|redis)" || echo "")
        fi
        
        for pod in $pods; do
            pod_name=$(basename $pod)
            
            # Vérifier que ce n'est pas un pod MariaDB ou Redis
            if echo "$pod_name" | grep -qE "(mariadb|redis)"; then
                log_info "Ignorer le pod $pod_name (base de données/cache)"
                continue
            fi
            
            log_info "Synchronisation des apps sur le pod: $pod_name"
            
            # Vérification que le pod est prêt
            if kubectl wait --for=condition=ready $pod -n $NAMESPACE --timeout=60s; then
                
                # Vérifier que bench est disponible
                if ! kubectl exec $pod -n $NAMESPACE -- which bench >/dev/null 2>&1; then
                    log_warn "Bench non trouvé sur $pod_name, c'est probablement un pod non-ERPNext, ignoré"
                    continue
                fi
                
                # Vérifier que le répertoire frappe-bench existe
                if ! kubectl exec $pod -n $NAMESPACE -- test -d /home/frappe/frappe-bench >/dev/null 2>&1; then
                    log_warn "Répertoire frappe-bench non trouvé sur $pod_name, ignoré"
                    continue
                fi
                
                # Installation des apps
                for app in "${APPS[@]}"; do
                    log_info "Vérification de l'app $app sur $pod_name..."
                    
                    # Vérifier si l'app existe déjà
                    if ! kubectl exec $pod -n $NAMESPACE -- test -d /home/frappe/frappe-bench/apps/$app >/dev/null 2>&1; then
                        log_info "Installation de $app sur $pod_name..."
                        if kubectl exec $pod -n $NAMESPACE -- bench get-app $app; then
                            log_info "✓ $app installée avec succès sur $pod_name"
                        else
                            log_warn "✗ Échec de l'installation de $app sur $pod_name"
                        fi
                    else
                        log_info "✓ $app déjà présente sur $pod_name"
                    fi
                done
                
                # Installation des apps sur le site (uniquement pour gunicorn pour éviter les conflits)
                if echo "$component" | grep -q "gunicorn"; then
                    log_info "Installation des apps sur le site pour $pod_name..."
                    for app in "${APPS[@]}"; do
                        if kubectl exec $pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com install-app $app 2>/dev/null; then
                            log_info "✓ $app installée sur le site via $pod_name"
                        else
                            log_warn "✗ $app déjà installée sur le site ou erreur"
                        fi
                    done
                fi
                
            else
                log_error "Pod $pod_name n'est pas prêt, passage au suivant"
            fi
        done
    done
    
    # Migration finale
    log_info "Exécution de la migration finale..."
    gunicorn_pods=$(get_erpnext_pods "gunicorn")
    if [ -z "$gunicorn_pods" ]; then
        # Fallback
        gunicorn_pods=$(kubectl get pods -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE -o name | grep gunicorn | head -1)
    fi
    
    if [ -n "$gunicorn_pods" ]; then
        gunicorn_pod=$(echo "$gunicorn_pods" | head -1)
        log_info "Utilisation du pod $gunicorn_pod pour la migration..."
        if kubectl exec $gunicorn_pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com migrate; then
            log_info "✓ Migration réussie"
        else
            log_warn "✗ Migration échouée"
        fi
    else
        log_error "Aucun pod gunicorn trouvé pour la migration"
    fi
}

# Fonction pour vérifier l'état des apps
check_apps_status() {
    log_info "Vérification de l'état des apps..."
    
    # Chercher un pod gunicorn
    gunicorn_pods=$(get_erpnext_pods "gunicorn")
    if [ -z "$gunicorn_pods" ]; then
        gunicorn_pods=$(kubectl get pods -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE -o name | grep gunicorn | head -1)
    fi
    
    if [ -n "$gunicorn_pods" ]; then
        gunicorn_pod=$(echo "$gunicorn_pods" | head -1)
        log_info "Utilisation du pod $(basename $gunicorn_pod) pour la vérification..."
        
        log_info "Apps installées sur le site:"
        kubectl exec $gunicorn_pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com list-apps || log_warn "Impossible de lister les apps"
        
        log_info "État des services:"
        kubectl exec $gunicorn_pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com doctor || log_warn "Bench doctor échoué"
        
        log_info "Statut des sites:"
        kubectl exec $gunicorn_pod -n $NAMESPACE -- bench --site erp-dev.amoaman.com version || log_warn "Impossible d'obtenir la version"
        
    else
        log_error "Aucun pod gunicorn trouvé"
        log_info "Pods disponibles:"
        kubectl get pods -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE
    fi
}

# Fonction pour redémarrer tous les workers ERPNext
restart_workers() {
    log_info "Redémarrage de tous les workers ERPNext..."
    
    # Noms des déploiements ERPNext (pas MariaDB/Redis)
    DEPLOYMENTS=(
        "$RELEASE_NAME-gunicorn"
        "$RELEASE_NAME-worker-default"
        "$RELEASE_NAME-worker-short" 
        "$RELEASE_NAME-worker-long"
        "$RELEASE_NAME-scheduler"
        "$RELEASE_NAME-socketio"
        "$RELEASE_NAME-nginx"
    )
    
    for deployment in "${DEPLOYMENTS[@]}"; do
        if kubectl get deployment "$deployment" -n $NAMESPACE >/dev/null 2>&1; then
            log_info "Redémarrage de $deployment..."
            kubectl rollout restart deployment/$deployment -n $NAMESPACE
        else
            log_warn "Déploiement $deployment non trouvé, ignoré"
        fi
    done
    
    log_info "Attente de la stabilisation des redémarrages..."
    for deployment in "${DEPLOYMENTS[@]}"; do
        if kubectl get deployment "$deployment" -n $NAMESPACE >/dev/null 2>&1; then
            kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=300s || log_warn "Timeout pour $deployment"
        fi
    done
}

# Fonction pour afficher les pods et leurs rôles
list_pods() {
    log_info "Liste des pods dans le namespace $NAMESPACE:"
    kubectl get pods -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE -o wide
    
    log_info "Pods ERPNext (avec bench):"
    kubectl get pods -l "app.kubernetes.io/instance=$RELEASE_NAME" -l "app.kubernetes.io/name=erpnext" -n $NAMESPACE 2>/dev/null || log_warn "Aucun pod avec le label app.kubernetes.io/name=erpnext trouvé"
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
        "list-pods")
            list_pods
            ;;
        *)
            echo "Usage: $0 {install|upgrade|sync-apps|restart|status|list-pods}"
            echo ""
            echo "Commands:"
            echo "  install    - Installation complète d'ERPNext avec apps"
            echo "  upgrade    - Mise à jour d'ERPNext avec synchronisation des apps"
            echo "  sync-apps  - Synchronise les apps sur tous les pods ERPNext uniquement"
            echo "  restart    - Redémarre tous les workers ERPNext"
            echo "  status     - Vérifie l'état des apps installées"
            echo "  list-pods  - Liste tous les pods et leurs rôles"
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