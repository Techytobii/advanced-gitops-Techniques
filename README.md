# advanced-gitops-Techniques

# ArgoCD — App-of-Apps Multi-Cluster Quickstart


## Goals

* Install Argo CD on a management cluster.
* Register two clusters (management + workload) into Argo CD.
* Use the App-of-Apps pattern: one parent Argo CD `Application` that declaratively creates child `Application` objects for each microservice.
* Deploy simple `frontend`, `backend`, and `postgres` services as examples.

---

## Prerequisites

* `kubectl` installed and configured with contexts for each cluster (e.g., `mgmt-cluster` and `workload-cluster`).
* `argocd` CLI installed.
* `helm` (optional, if using Helm charts for apps).
* A Git repository to host Argo manifests
---

## Repo layout (example)

```
├── apps
│   ├── app-of-apps.yaml            # Parent Application
│   ├── backend.yaml                # Child Application (kustomize)
│   ├── frontend.yaml               # Child Application (kustomize)
│   └── postgres.yaml               # Child Application (helm)
├── services
│   ├── backend
│   │   ├── base
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays
│   │       └── dev
│   │           └── kustomization.yaml
│   └── frontend
│       └── ...
└── .github
    └── workflows
        └── argocd-sync.yml
```

---

1. **Install Argo CD in the management cluster**

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

2. **Grab the initial admin password and login to argocd CLI**

```bash
# get admin password (one-liner)
kubectl -n argocd get secret argocd-secret -o jsonpath="{.data.admin\.password}" | base64 -d; echo

# login (replace <ARGO_SERVER> with port-forward or LB) - if using port-forward:
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --insecure --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
```

3. **Register workload cluster(s) with ArgoCD**

```bash
# Ensure your kubeconfig context names exist (kubectl config get-contexts)
# Add a cluster (from your local environment) to ArgoCD:
argocd cluster add CONTEXT_NAME_FOR_WORKLOAD_CLUSTER

# Repeat for additional clusters as needed
```

4. **Push the repo structure to your Git repo** (or use the example repo). Make sure `apps/` and `services/` are present.

5. **Apply the parent Application (App-of-Apps) in ArgoCD**

```bash
# either kubectl apply -f apps/app-of-apps.yaml -n argocd
# or use argocd CLI to create from the repo
argocd app create apps \
  --repo https://github.com/Techytobii/introduction-2-gitops-agrocd.git \
  --path apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd

argocd app sync apps
```

6. **Verify**

```bash
argocd app list
argocd app get apps
argocd app sync -l app.kubernetes.io/instance=apps
kubectl get all -n backend  # or whichever namespace your child app targets
```

---

# Full manifests & code (copy-paste)

> Note: **Do not** commit secrets to Git. Replace `repoURL`, `targetRevision`, and image names for your environment.

## 1) Parent Application (`apps/app-of-apps.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/Techytobii/introduction-2-gitops-agrocd.git
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 2) Child Application — Backend (kustomize) (`apps/backend.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/Techytobii/introduction-2-gitops-agrocd.git
    targetRevision: HEAD
    path: services/backend/overlays/dev
  destination:
    server: https://kubernetes.default.svc  # replace with workload cluster server if deploying to other cluster
    namespace: backend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 3) Child Application — Frontend (kustomize) (`apps/frontend.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Techytobii/introduction-2-gitops-agrocd.git
    targetRevision: HEAD
    path: services/frontend/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 4) Child Application — Postgres (Helm) (`apps/postgres.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgres
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: postgresql
    targetRevision: 12.0.0  # pin a chart version
    helm:
      values: |-
        global:
          postgresql:
            postgresqlPassword: REPLACE_ME  # store as secret in real deployments
  destination:
    server: https://kubernetes.default.svc
    namespace: postgres
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

> Alternative: Use a Git repo source for Helm values (recommended) — commit a `values.yaml` to `services/postgres` and change `repoURL` and `path` accordingly.

---

# Example microservice manifests (backend) — Kustomize base

`services/backend/base/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: nginx:1.21-alpine   # replace with your backend image
          ports:
            - containerPort: 80
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
```

`services/backend/base/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```

`services/backend/base/kustomization.yaml`

```yaml
resources:
  - deployment.yaml
  - service.yaml
```

`services/backend/overlays/dev/kustomization.yaml`

```yaml
resources:
  - ../../base

# example patch: change replica count
patches:
  - patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: backend
      spec:
        replicas: 2
    target:
      kind: Deployment
      name: backend
```

---

# GitHub Actions: optional auto-sync workflow template

Save as `.github/workflows/argocd-sync.yml` if you want an action to call ArgoCD CLI to force a sync after pushes (requires repo secrets).

```yaml
name: Trigger ArgoCD sync
on:
  push:
    branches: [ main ]

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install argocd CLI
        run: |
          curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
          chmod +x /usr/local/bin/argocd

      - name: Login to ArgoCD
        env:
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
          ARGOCD_USERNAME: ${{ secrets.ARGOCD_USERNAME }}
          ARGOCD_PASSWORD: ${{ secrets.ARGOCD_PASSWORD }}
        run: |
          argocd login $ARGOCD_SERVER --username $ARGOCD_USERNAME --password $ARGOCD_PASSWORD --insecure

      - name: Sync parent app
        run: |
          argocd app sync apps
```

**Secrets required:** `ARGOCD_SERVER` (e.g. `argocd.example.com:443`), `ARGOCD_USERNAME`, `ARGOCD_PASSWORD`. Use short-lived tokens or OAuth where possible.

---

# Multi-cluster specifics

* When creating a child `Application` that should deploy to another cluster, set `destination.server` to that cluster's API server URL (the cluster must already be added to ArgoCD using `argocd cluster add <context>`).

Example: find the cluster server URL for a kubecontext:

```bash
kubectl --context=workload-cluster config view -o jsonpath='{.clusters[0].cluster.server}'
```

Then use that value in the child `Application`:

```yaml
destination:
  server: https://1.2.3.4:6443
  namespace: backend
```

(Argo CD stores credentials/secrets when you run `argocd cluster add` so the server URL must match an entry in Argo CD's known clusters.)

---

# Verification & Troubleshooting

* List Argo CD apps: `argocd app list`
* Check app status: `argocd app get backend --refresh`
* See sync history: `argocd app history backend`
* Sync logs: `argocd app logs backend`
* If child apps are stuck `OutOfSync`, inspect the child Application manifests in the `apps/` folder and ensure paths & repoURL are correct.
* Common issues:

  * Wrong `destination.server` for multi-cluster apps → register cluster with `argocd cluster add` and set correct server URL.
  * RBAC: Projects and creating applications in arbitrary namespaces is admin-level. Only admins should push the parent app.
  * Secrets in charts: use ExternalSecret/SealedSecrets or Argo CD Secrets plugin — never commit DB passwords in plaintext.

---

# Security & Best Practices (short list)

* Pin `targetRevision` to a commit SHA for production-critical apps.
* Use `finalizers` on parent app if you want cascading deletion to remove child apps.
* Use `ArgocdAppProject` to enforce which namespaces/repos each app can access.
* Store credentials in a secrets manager or Git-crypt/sealed-secrets.
* Use network policies and RBAC to limit access between frontend/backend.

---

# Next steps I can help with

* Tailor all manifests to your specific repo (`https://github.com/Techytobii/introduction-2-gitops-agrocd.git`).
* Create the exact files and push them as a PR to your repo (I can provide the patch content to paste).
* Create a Helm-based App-of-Apps parent chart instead of raw YAML.

---

Happy to adapt anything — tell me which cluster names / target images / repo paths you want me to customize and I will update the manifests.
