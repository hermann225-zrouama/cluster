class AdaptiveExplainableEnsemble:
    def __init__(self, 
                 n_trees=100,
                 learning_rate=0.1,  # Nouveau : apprentissage progressif
                 adaptive_explicability=True,  # Nouveau
                 boosting_strategy='gradient_explicable'):  # Nouveau
        
        self.learning_rate = learning_rate
        self.adaptive_explicability = adaptive_explicability
        self.boosting_strategy = boosting_strategy
        self.residual_calculator = ExplainableResidualCalculator()
        
    def fit_adaptive(self, X, y):
        """
        Apprentissage adaptatif avec explicabilité préservée
        """
        # Initialisation avec un modèle simple très explicable
        initial_tree = self.build_highly_explainable_tree(X, y)
        self.trees = [initial_tree]
        
        current_predictions = initial_tree.predict(X)
        
        for i in range(1, self.n_trees):
            # Calcul des résidus explicables
            residuals, residual_explanations = self.residual_calculator.compute_explainable_residuals(
                y, current_predictions, X
            )
            
            # Construction du prochain arbre sur les résidus
            # avec poids adaptatif d'explicabilité
            explicability_weight = self.compute_adaptive_explicability_weight(
                i, residuals, residual_explanations
            )
            
            next_tree = self.build_explainable_tree(
                X, residuals, 
                explicability_weight=explicability_weight
            )
            
            # Ajout avec learning rate
            self.trees.append(next_tree)
            tree_predictions = next_tree.predict(X)
            current_predictions += self.learning_rate * tree_predictions
            
            # Early stopping basé sur explicabilité + performance
            if self.should_stop_early(X, y, current_predictions, i):
                break
                
        return self

def compute_adaptive_explicability_weight(self, iteration, residuals, explanations):
    """
    Poids d'explicabilité adaptatif selon la complexité des résidus
    """
    # Plus les résidus sont complexes, moins on contraint l'explicabilité
    residual_complexity = np.std(residuals)
    base_weight = self.explicability_weight
    
    # Réduction progressive pour permettre l'apprentissage de patterns complexes
    iteration_factor = 1.0 - (iteration / self.n_trees) * 0.5
    complexity_factor = 1.0 / (1.0 + residual_complexity)
    
    adaptive_weight = base_weight * iteration_factor * complexity_factor
    return np.clip(adaptive_weight, 0.1, 0.8)  # Bornes de sécurité

class RobustExplainableTree:
    def __init__(self):
        self.missing_value_handler = ExplainableMissingValueHandler()
        self.outlier_detector = ExplainableOutlierDetector()
        self.categorical_encoder = ExplainableCategoricalEncoder()
        
    def handle_missing_values_explainably(self, X, feature_idx, node_samples):
        """
        Gestion explicable des valeurs manquantes
        """
        missing_mask = pd.isna(X[node_samples, feature_idx])
        
        if missing_mask.sum() == 0:
            return X, "No missing values"
        
        # Stratégies explicables
        strategies = {
            'median_substitution': self.substitute_with_median,
            'mode_substitution': self.substitute_with_mode,
            'predictive_substitution': self.substitute_with_prediction,
            'missing_as_category': self.treat_missing_as_category
        }
        
        # Choix de stratégie basé sur l'explicabilité et la performance
        best_strategy = self.select_explainable_strategy(
            X, feature_idx, node_samples, missing_mask, strategies
        )
        
        X_imputed, explanation = strategies[best_strategy](
            X, feature_idx, node_samples, missing_mask
        )
        
        return X_imputed, f"Missing values handled by {best_strategy}: {explanation}"

def detect_explainable_outliers(self, X, y, node_samples):
    """
    Détection d'outliers avec justification explicable
    """
    # Méthodes explicables : IQR, Z-score avec seuils compréhensibles
    outlier_explanations = []
    clean_samples = node_samples.copy()
    
    for feature_idx in range(X.shape[1]):
        feature_values = X[node_samples, feature_idx]
        
        # Détection IQR (facilement explicable)
        Q1, Q3 = np.percentile(feature_values, [25, 75])
        IQR = Q3 - Q1
        lower_bound = Q1 - 1.5 * IQR
        upper_bound = Q3 + 1.5 * IQR
        
        outlier_mask = (feature_values < lower_bound) | (feature_values > upper_bound)
        
        if outlier_mask.sum() > 0:
            outlier_explanations.append({
                'feature': self.feature_names[feature_idx],
                'method': 'IQR',
                'bounds': (lower_bound, upper_bound),
                'n_outliers': outlier_mask.sum(),
                'outlier_indices': node_samples[outlier_mask]
            })
            
            # Retrait des outliers pour ce nœud
            clean_samples = clean_samples[~outlier_mask]
    
    return clean_samples, outlier_explanations

class OptimizedExplainableEnsemble:
    def __init__(self):
        self.feature_sampler = ExplainableFeatureSampler()
        self.memory_optimizer = ExplanationMemoryOptimizer()
        self.gpu_accelerator = ExplainableGPUAccelerator()
        
    def optimized_tree_construction(self, X, y):
        """
        Construction d'arbre optimisée avec explicabilité préservée
        """
        # 1. Échantillonnage intelligent des features
        selected_features, feature_explanation = self.feature_sampler.sample_explainable_features(
            X, y, n_features=int(np.sqrt(X.shape[1]))
        )
        
        # 2. Approximation d'histogrammes pour splits rapides
        if X.shape[0] > 10000:  # Pour gros datasets
            X_binned, bin_explanations = self.create_explainable_bins(X[:, selected_features])
            tree = self.build_tree_on_bins(X_binned, y, bin_explanations)
        else:
            tree = self.build_standard_tree(X[:, selected_features], y)
        
        # 3. Compression des explications
        tree.explanations = self.memory_optimizer.compress_explanations(tree.explanations)
        
        return tree
        
    def parallel_ensemble_training(self, X, y):
        """
        Entraînement parallèle avec cohérence des explications
        """
        from concurrent.futures import ProcessPoolExecutor
        import multiprocessing as mp
        
        n_cores = min(mp.cpu_count(), self.n_trees)
        trees_per_core = self.n_trees // n_cores
        
        # Préparation des graines pour reproductibilité
        seeds = [self.random_state + i for i in range(n_cores)]
        
        with ProcessPoolExecutor(max_workers=n_cores) as executor:
            futures = []
            
            for core_idx in range(n_cores):
                n_trees_core = trees_per_core + (1 if core_idx < self.n_trees % n_cores else 0)
                
                future = executor.submit(
                    self.train_trees_batch,
                    X, y, n_trees_core, seeds[core_idx]
                )
                futures.append(future)
            
            # Collecte des résultats
            all_trees = []
            for future in futures:
                batch_trees = future.result()
                all_trees.extend(batch_trees)
        
        self.trees = all_trees
        
        # Consolidation des explications globales
        self.consolidate_parallel_explanations()
        
        return self
    
class ExplainableRegularization:
    def __init__(self, l1_penalty=0.01, l2_penalty=0.01, complexity_penalty=0.1):
        self.l1_penalty = l1_penalty
        self.l2_penalty = l2_penalty  
        self.complexity_penalty = complexity_penalty
        
    def compute_regularized_split_score(self, split_score, node_info, tree_state):
        """
        Score de split avec régularisation explicable
        """
        base_score = split_score
        
        # L1 : Parcimonie des features (favorise moins de features)
        l1_term = self.l1_penalty * len(tree_state['used_features'])
        
        # L2 : Lissage des seuils (favorise des valeurs "rondes")
        threshold_complexity = self.compute_threshold_complexity(node_info['threshold'])
        l2_term = self.l2_penalty * threshold_complexity
        
        # Complexité : Pénalise la profondeur excessive
        depth_penalty = self.complexity_penalty * (node_info['depth'] ** 2)
        
        # Cohérence : Bonus pour cohérence avec règles existantes
        coherence_bonus = self.compute_rule_coherence_bonus(node_info, tree_state)
        
        regularized_score = (base_score 
                           - l1_term 
                           - l2_term 
                           - depth_penalty 
                           + coherence_bonus)
        
        return regularized_score
        
    def compute_threshold_complexity(self, threshold):
        """
        Mesure de complexité d'un seuil (favorise valeurs simples)
        """
        # Valeurs "rondes" ont une complexité moindre
        if abs(threshold - round(threshold)) < 0.01:
            return 0.1  # Très simple
        elif abs(threshold - round(threshold, 1)) < 0.01:
            return 0.3  # Assez simple
        else:
            return 1.0  # Complexe
        
class ExplainableValidation:
    def __init__(self, patience=10, min_explicability_score=0.6):
        self.patience = patience
        self.min_explicability_score = min_explicability_score
        self.validation_history = []
        
    def should_stop_early(self, X_val, y_val, current_ensemble, iteration):
        """
        Early stopping basé sur performance ET explicabilité
        """
        # Métriques de performance
        val_predictions = current_ensemble.predict(X_val)
        val_performance = self.compute_performance_metric(y_val, val_predictions)
        
        # Métriques d'explicabilité
        val_explicability = current_ensemble.evaluate_explicability(X_val, y_val)
        
        # Score combiné
        combined_score = (0.7 * val_performance + 
                         0.3 * val_explicability['explicability_score'])
        
        self.validation_history.append({
            'iteration': iteration,
            'performance': val_performance,
            'explicability': val_explicability['explicability_score'],
            'combined_score': combined_score
        })
        
        # Conditions d'arrêt
        # 1. Explicabilité minimale non respectée
        if val_explicability['explicability_score'] < self.min_explicability_score:
            return True, "Explicability threshold not met"
        
        # 2. Pas d'amélioration depuis 'patience' itérations
        if len(self.validation_history) >= self.patience:
            recent_scores = [h['combined_score'] for h in self.validation_history[-self.patience:]]
            if all(score <= recent_scores[0] + 1e-4 for score in recent_scores[1:]):
                return True, "No improvement in combined score"
        
        # 3. Surapprentissage détecté
        if len(self.validation_history) >= 5:
            performance_trend = np.polyfit(
                range(5), 
                [h['performance'] for h in self.validation_history[-5:]], 
                1
            )[0]
            explicability_trend = np.polyfit(
                range(5), 
                [h['explicability'] for h in self.validation_history[-5:]], 
                1
            )[0]
            
            if performance_trend < -0.001 and explicability_trend < -0.01:
                return True, "Overfitting detected (both metrics declining)"
        
        return False, "Continue training"
    
class ETEAPlus:
    """
    Version améliorée intégrant toutes les optimisations
    """
    def __init__(self, 
                 n_trees=100,
                 learning_rate=0.1,
                 max_depth=6,
                 min_samples_split=20,
                 explicability_weight=0.3,
                 adaptive_explicability=True,
                 boosting_strategy='gradient_explicable',
                 regularization=True,
                 optimization_level='high'):
        
        # Composants principaux
        self.adaptive_learner = AdaptiveExplainableEnsemble(...)
        self.robust_trees = RobustExplainableTree(...)
        self.optimizer = OptimizedExplainableEnsemble(...)
        self.regularizer = ExplainableRegularization(...)
        self.validator = ExplainableValidation(...)
        
        # Intégration des améliorations
        self.missing_handler = True
        self.outlier_detection = True
        self.gpu_acceleration = optimization_level == 'high'
        self.parallel_training = optimization_level in ['medium', 'high']
        
    def fit(self, X, y, X_val=None, y_val=None):
        """
        Entraînement avec toutes les améliorations
        """
        # Phase 1: Préparation robuste des données
        X_processed, preprocessing_explanations = self.robust_preprocessing(X)
        
        # Phase 2: Entraînement adaptatif
        if self.adaptive_explicability:
            self.adaptive_learner.fit_adaptive(X_processed, y)
        else:
            self.fit_standard_ensemble(X_processed, y)
        
        # Phase 3: Validation et early stopping
        if X_val is not None:
            self.apply_early_stopping(X_val, y_val)
        
        # Phase 4: Post-processing et optimisation mémoire
        self.optimize_final_model()
        
        return self
    
