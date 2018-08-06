#!/bin/bash

source ../env.sh

kubectl create secret generic traefik-ssl --from-file=/etc/kubernetes/ssl/ca-key.pem --from-file=/etc/kubernetes/ssl/ca.pem -n kube-system

cat >> ingress-rbac.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ingress
  namespace: kube-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: ingress
subjects:
  - kind: ServiceAccount
    name: ingress
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

cat >> traefik-daemonset.yaml << EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: traefik-conf
  namespace: kube-system
data:
  traefik-config: |-
    defaultEntryPoints = ["http","https"]
    [entryPoints]
      [entryPoints.http]
      address = ":80"
        [entryPoints.http.redirect]
          entryPoint = "https"
      [entryPoints.https]
      address = ":443"
        [entryPoints.https.tls]
          [[entryPoints.https.tls.certificates]]
          CertFile = "/ssl/ca.pem"
          KeyFile = "/ssl/ca-key.pem"

---
kind: DaemonSet
apiVersion: extensions/v1beta1
metadata:
  name: traefik-ingress
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress
spec:
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress
        name: traefik-ingress
    spec:
      terminationGracePeriodSeconds: 60
      restartPolicy: Always
      serviceAccountName: ingress
      containers:
      - image: traefik:latest
        name: traefik-ingress
        ports:
        - name: http
          containerPort: 80
          hostPort: 80
        - name: https
          containerPort: 443
          hostPort: 443
        - name: admin
          containerPort: 8080
        args:
        - --configFile=/etc/traefik/traefik.toml
        - -d
        - --web
        - --kubernetes
        - --logLevel=DEBUG
        volumeMounts:
        - name: traefik-config-volume
          mountPath: /etc/traefik
        - name: traefik-ssl-volume
          mountPath: /ssl
      volumes:
      - name: traefik-config-volume
        configMap:
          name: traefik-conf
          items:
          - key: traefik-config
            path: traefik.toml
      - name: traefik-ssl-volume
        secret:
          secretName: traefik-ssl
EOF

cat >> traefik-ingress.yaml << EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-ingress
spec:
  rules:
  - host: traefik.nginx.io
    http:
      paths:
      - path: /
        backend:
          serviceName: my-nginx
          servicePort: 80
EOF

cat >> traefik-ui.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: traefik-ui
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress
  ports:
  - name: web
    port: 80
    targetPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-ui
  namespace: kube-system
spec:
  rules:
  - host: traefik-ui.local
    http:
      paths:
      - path: /
        backend:
          serviceName: traefik-ui
          servicePort: web
EOF

## testing
sed -i '/test04/ s/$/ traefik.nginx.io traefik-ui.local/' /etc/hosts
firefox https://traefik-ui.local
firefox https://traefik.nginx.io
