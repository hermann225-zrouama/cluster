#!/bin/bash
# deploy.sh - Script pour construire et déployer votre image personnalisée

set -e

# Variables
IMAGE_NAME="zetsu225/erpnext-test"
TAG="latest"
HELM_RELEASE="frappe-bench"
NAMESPACE="erp-test"
VALUES_FILE="values.yaml"

echo "=== Déploiement ERPNext avec image personnalisée ==="

# 1. Construire l'image Docker
echo "1. Construction de l'image Docker..."
docker build -t "${IMAGE_NAME}:${TAG}" .

# 2. Pousser l'image vers le registry
echo "2. Push de l'image vers le registry..."
docker push "${IMAGE_NAME}:${TAG}"

# 3. Déployer avec Helm
echo "3. Déploiement avec Helm..."

# Vérifier si le release existe déjà
if helm list -n ${NAMESPACE} | grep -q ${HELM_RELEASE}; then
    echo "Mise à jour du release existant..."
    helm upgrade ${HELM_RELEASE} frappe/erpnext \
        -n ${NAMESPACE} \
        -f ${VALUES_FILE} \
        --wait \
        --timeout=20m
else
    echo "Installation du nouveau release..."
    helm install ${HELM_RELEASE} frappe/erpnext \
        -n ${NAMESPACE} \
        -f ${VALUES_FILE} \
        --wait \
        --timeout=20m
fi

# 4. Vérifier le déploiement
echo "4. Vérification du déploiement..."
kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=erpnext

echo "=== Déploiement terminé ==="
echo "Accédez à votre ERPNext via: https://erp-test.amoaman.com"