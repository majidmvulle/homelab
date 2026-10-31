## Metallb
```bash
helm upgrade --install metallb metallb/metallb \
  --create-namespace \
  --namespace metallb-system \
  --version 0.15.3
```

```bash
kubectl apply -f bootstrap/metallb/config.yaml -n metallb-system 
```

## Longhorn

```bash
helm install longhorn longhorn/longhorn \
      --namespace longhorn-system \
      --create-namespace \
      --version 1.10.1 \
      -f bootstrap/longhorn/values.yaml
```
```bash
kubectl apply -f bootstrap/longhorn/storage-classes.yaml
```
```bash
kubectl apply -f bootstrap/longhorn/settings/
```

## ArgoCD

```bash
kubectl apply -f bootstrap/argocd/bootstrap.yaml -n argocd
```
