# Makefile pour ERPNext Helm

# Variables
IMAGE_NAME=zetsu225/erpnext
TAG=latest
HELM_RELEASE=frappe-bench
NAMESPACE=erp-test
VALUES_FILE=values.yaml

.PHONY: help build push deploy upgrade status logs clean

help: ## Afficher cette aide
	@echo "Commandes disponibles:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Construire l'image Docker
	docker build -t $(IMAGE_NAME):$(TAG) .

push: build ## Construire et pousser l'image
	docker push $(IMAGE_NAME):$(TAG)

deploy: push ## Déployer avec Helm (nouveau)
	helm install $(HELM_RELEASE) frappe/erpnext \
		-n $(NAMESPACE) \
		-f $(VALUES_FILE) \
		--wait \
		--timeout=20m

upgrade: push ## Mettre à jour le déploiement existant
	helm upgrade $(HELM_RELEASE) frappe/erpnext \
		-n $(NAMESPACE) \
		-f $(VALUES_FILE) \
		--wait \
		--timeout=20m

status: ## Voir le statut du déploiement
	@echo "=== Status Helm ==="
	helm status $(HELM_RELEASE) -n $(NAMESPACE)
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=erpnext
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n $(NAMESPACE) -l app.kubernetes.io/name=erpnext

logs: ## Voir les logs du pod principal
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=erpnext-gunicorn --tail=100 -f

shell: ## Accéder au shell d'un pod ERPNext
	kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app.kubernetes.io/component=erpnext-gunicorn -o jsonpath='{.items[0].metadata.name}') -- /bin/bash

backup: ## Lancer une sauvegarde manuelle
	kubectl create job -n $(NAMESPACE) --from=cronjob/$(HELM_RELEASE)-backup backup-manual-$$(date +%Y%m%d-%H%M%S)

clean: ## Supprimer le déploiement
	helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)

# Commandes avancées
force-upgrade: ## Forcer la mise à jour (recrée les pods)
	helm upgrade $(HELM_RELEASE) frappe/erpnext \
		-n $(NAMESPACE) \
		-f $(VALUES_FILE) \
		--force \
		--wait \
		--timeout=20m

rollback: ## Revenir à la version précédente
	helm rollback $(HELM_RELEASE) -n $(NAMESPACE)

debug: ## Mode debug pour diagnostiquer les problèmes
	helm install $(HELM_RELEASE) frappe/erpnext \
		-n $(NAMESPACE) \
		-f $(VALUES_FILE) \
		--debug \
		--dry-run