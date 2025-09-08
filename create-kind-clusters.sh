#!/usr/bin/env bash
set -euo pipefail

for name in control dev-1 dev-2; do
  kind create cluster --name "$name" --wait 60s
done

echo "Clusters created: kind-control, kind-dev-1, kind-dev-2"
kubectl config get-contexts

