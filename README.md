# Advanced GitOps with ArgoCD (App-of-Apps, Multi-Cluster, and Microservices)

---

## 📖 Introduction

This project demonstrates advanced GitOps techniques using **ArgoCD**, focusing on:

* Multi-cluster deployments
* Microservices architectures
* App-of-Apps pattern for cluster bootstrapping
* Integration into CI/CD pipelines (via GitHub Actions)

By the end of this project, you will:

* Deploy multiple microservices across clusters
* Manage applications declaratively through Git
* Understand how to scale and operate real-world GitOps workflows

---

## 🎯 Objectives

* Install and configure **ArgoCD** in a management cluster.
* Use the **App-of-Apps** pattern to manage multiple applications.
* Deploy example microservices (`frontend`, `backend`, `postgres`) across clusters.
* Enable automation using GitHub Actions for continuous delivery.

---

## ✅ Prerequisites

* **Tools installed locally:**

  * `kubectl`
  * `argocd` CLI
  * `helm` (optional, if deploying Helm charts)
* **Clusters:**

  * At least two Kubernetes clusters (1 management + 1 workload)
* **Git repository** (example: [introduction-2-gitops-agrocd](https://github.com/Techytobii/introduction-2-gitops-agrocd.git))
* Basic knowledge of Kubernetes manifests, Helm, and Kustomize.

---

## ⚡ Quickstart Guide

### Step 1: Install ArgoCD in Management Cluster

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Step 2: Access ArgoCD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --insecure --username admin --password <PASTE_PASSWORD>
```

### Step 3: Register Workload Clusters

```bash
argocd cluster add CONTEXT_NAME_FOR_WORKLOAD_CLUSTER
```

### Step 4: Apply Parent App (App-of-Apps)

```bash
kubectl apply -f apps/app-of-apps.yaml -n argocd
argocd app sync apps
```

### Step 5: Verify Deployment

```bash
argocd app list
argocd app get apps
kubectl get all -n backend
```

---

## 📂 Repository Structure

```
apps/
 ├── app-of-apps.yaml        # Parent application
 ├── backend.yaml            # Backend child app
 ├── frontend.yaml           # Frontend child app
 └── postgres.yaml           # Postgres child app

services/
 ├── backend/
 │   ├── base/
 │   │   ├── deployment.yaml
 │   │   ├── service.yaml
 │   │   └── kustomization.yaml
 │   └── overlays/dev/
 │       └── kustomization.yaml
 └── frontend/
     └── ...
```

---

## 📝 Example Manifests

### Parent Application (`apps/app-of-apps.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
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

### Child Application (Backend — Kustomize)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Techytobii/introduction-2-gitops-agrocd.git
    targetRevision: HEAD
    path: services/backend/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: backend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Microservice Deployment (Backend — `services/backend/base/deployment.yaml`)

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
          image: nginx:1.21-alpine
          ports:
            - containerPort: 80
```

---

## 🔄 CI/CD Integration (Optional)

You can integrate GitHub Actions to trigger ArgoCD sync on every push.

```yaml
name: Trigger ArgoCD sync
on:
  push:
    branches: [ main ]
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install argocd CLI
        run: |
          curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
          chmod +x /usr/local/bin/argocd
      - name: Login & Sync
        env:
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
          ARGOCD_USERNAME: ${{ secrets.ARGOCD_USERNAME }}
          ARGOCD_PASSWORD: ${{ secrets.ARGOCD_PASSWORD }}
        run: |
          argocd login $ARGOCD_SERVER --username $ARGOCD_USERNAME --password $ARGOCD_PASSWORD --insecure
          argocd app sync apps
```

---

## ⚠️ Challenges Faced

* Managing multiple clusters requires correct `destination.server` values.
* Secrets handling: avoid committing passwords directly (use **SealedSecrets** or **ExternalSecrets**).
* Sync conflicts may occur if cluster drift is significant.
* Helm vs Kustomize: different teams may prefer one, so mixed usage must be handled carefully.

---

## 🔍 Verification & Troubleshooting

* **List apps:** `argocd app list`
* **Check status:** `argocd app get backend --refresh`
* **View history:** `argocd app history backend`
* **Logs:** `argocd app logs backend`

---

## 🚀 Conclusion

Using ArgoCD with the **App-of-Apps pattern** enables scalable GitOps workflows for:

* Multi-cluster environments
* Microservices architectures
* Declarative deployments through Git
