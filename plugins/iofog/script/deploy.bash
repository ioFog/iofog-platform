#!/bin/bash

set -e

OS=$(uname -s | tr A-Z a-z)
HELM=plugins/iofog/helm
SCRIPT=plugins/iofog/script
ANSIBLE=plugins/iofog/ansible
export KUBECONFIG=conf/kube.conf

# Wait for Kubernetes cluster
"$SCRIPT"/wait-for-pods.bash kube-system

# Helm
helm init --wait
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
kubectl rollout status --watch deployment/tiller-deploy -n kube-system

# ioFog core on Kubernetes
kubectl create namespace iofog
helm install "$HELM"/iofog
echo "Waiting for Controller Pod..."
"$SCRIPT"/wait-for-pods.bash iofog name=controller
echo "Waiting for Controller LoadBalancer IP..."
IP=$("$SCRIPT"/wait-for-lb.bash iofog controller)
PORT=51121
TOKEN=$("$SCRIPT"/get-controller-token.bash "$IP" "$PORT")
helm install "$HELM"/iofog-k8s --set-string controller.token="$TOKEN"

# Agents
CTRL_IP=$("$SCRIPT"/wait-for-lb.bash iofog controller)
"$SCRIPT"/add-agent-hosts.bash $(cat conf/agents.conf)
echo "$OS"
if [ "$OS" == "darwin" ]; then
	sed -i '' -e "s/controller_ip=.*/controller_ip=$CTRL_IP/g" "$ANSIBLE"/hosts
else
	sed -i "s/controller_ip=.*/controller_ip=$CTRL_IP/g" "$ANSIBLE"/hosts
fi
ANSIBLE_CONFIG="$ANSIBLE" ansible-playbook -i "$ANSIBLE"/hosts "$ANSIBLE"/iofog-agent.yml