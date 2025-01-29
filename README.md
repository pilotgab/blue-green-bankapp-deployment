# 2. Installing Datadog to K8s Cluster
Refs: 
- https://docs.datadoghq.com/getting_started/agent/
- https://docs.datadoghq.com/agent/kubernetes/?tab=helm


## 2.0 Create EKS Cluster (minikube won't work)
Ref: https://kubernetes.io/docs/tutorials/hello-minikube/

Create EKS cluster
```sh
export AWS_PROFILE=aws-demo
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="eks-from-eksctl"
ACCOUNT_ID=266981300450

eksctl create cluster \
    --name ${CLUSTER_NAME} \
    --version 1.21 \
    --region ${AWS_REGION} \
    --nodegroup-name workers \
    --node-type t3.large \
    --nodes 1 \
    --nodes-min 1 \
    --nodes-max 2 \
    --ssh-access \
    --ssh-public-key ~/.ssh/aws-demo/eks-demo-workers.pem.pub \
    --managed

# eksctl delete cluster --name ${CLUSTER_NAME} --region ${AWS_REGION}
```

Deploy guestbook app: 
```sh
mkdir sandbox && cd sandbox
git clone https://github.com/kubernetes/examples.git
k apply -f examples/guestbook


kubectl create namespace ingress-nginx

# ref: https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx

# create ingress resource
k apply -f sandbox/
```


## 2.1 Configuration for K8s

Depending on your infra setup, Datadog agent can be installed on a host as a process, or can be deployed as a k8s pod (daemonset: one pod per node).

Doc > Getting Started > Agent > K8s
![alt text](../imgs/install_agent_k8s.png "")
![alt text](../imgs/install_agent_k8s2.png "")


Or if you sign up for a new free account:
![alt text](../imgs/datadog_account_signup_agent_installation_k8s.png "")


To install the chart with a custom release name, RELEASE_NAME (e.g. datadog-agent):

- Install Helm.
- Add Datadog Helm repository: helm repo add datadog https://helm.datadoghq.com.
- Add stable repository (for kube-state-metrics chart): helm repo add stable https://charts.helm.sh/stable.
- Fetch latest version of newly added charts: helm repo update.
- Download the Datadog values.yaml configuration file.
- Deploy the Datadog Agent with:


```sh
# from the root of the repo

# Add Datadog Helm repository
helm repo add datadog https://helm.datadoghq.com

# Add stable repository
helm repo add stable https://charts.helm.sh/stable

# Fetch latest version of newly added charts
helm repo update

# Download the Datadog values.yaml configuration file
helm show values datadog/datadog > overrides.yaml

helm install datadog \
  -f overrides.yaml \
  --set datadog.apiKey='YOUR_KEY' \
  datadog/datadog 
```

![alt text](../imgs/install_agent_k8s3.png "")

This chart adds the Datadog Agent to __all nodes in your cluster via a DaemonSet__. It also optionally deploys the kube-state-metrics chart and uses it as an additional source of metrics about the cluster. A few minutes after installation, Datadog begins to report hosts and metrics.


### Enable K8s Integration from Dashboard

![alt text](../imgs/enable_k8s_integration.png "")
![alt text](../imgs/enable_k8s_integration2.png "")



## 2.2 Data Collected by Datadog Agent
Ref: https://docs.datadoghq.com/getting_started/agent/#data-collected


![alt text](../imgs/agent_metrics_collected.png "")



## 2.3 Agent Architecture
Ref: https://docs.datadoghq.com/agent/basic_agent_usage/?tab=agentv6v7#agent-architecture


The two main components to the agent process is:
- __Collector__: collect and checks metrics every 15 seconds
- __Forwarder__: send payloads over HTTPS to Datadog


There are two more optional processes that can be enabled:
- __APM Agent__ is a process to collect traces
- __Process Agent__ is a process to collect live process information. By default, it only collects available containers, otherwise it is disabled



## 2.4 Agent overhead
Ref: https://docs.datadoghq.com/agent/basic_agent_usage/?tab=agentv6v7#agent-overhead

Tested on AWS EC2 machine c5.xlarge instance (4 VCPU/ 8GB RAM)

- Agent Test version: 6.7.0
- CPU: __~ 0.12% of the CPU__ used on average
- Memory: __~ 60MB of RAM__ used (RSS memory)
- Network bandwidth: ~ 86 B/s ▼ | 260 B/s ▲
- Disk:
  - Linux 350MB to 400MB depending on the distribution
  - Windows: 260MB




## 2.5 (Best Practice) How to Exclude Containers from Logs & Metrics Collection

Refs: 
- https://docs.datadoghq.com/agent/kubernetes/?tab=helm#ignore-containers
- https://docs.datadoghq.com/agent/guide/autodiscovery-management/?tab=containerizedagent


### 2.5.1 Limit data collection to a subset of containers only

Datadog Agent __auto-discovers all containers available by default__. To restrict its discovery perimeter and limit data collection to a subset of containers only, include or exclude them through a dedicated configuration.


Scenarios:
- you might want to avoid collecting logs from irrelevant containers such as `coredns`, `efs-csi-node`, `kube-proxy`, and `metrics-server` in `kube-system` to save cost
- you definitely want to avoid collecting logs from istio proxy container to save cost


To exclude containers, you can use these envs:
- `DD_CONTAINER_EXCLUDE`
- `DD_CONTAINER_EXCLUDE_METRICS`
- `DD_CONTAINER_EXCLUDE_LOGS`

And three keys:
- `name:`
- `image:`
- `kube_namespace:`


For exampple, if you want to exclude logs from image name `nginx`, then you would use
```yaml
agent:
  env: 
  - name: DD_CONTAINER_EXCLUDE_LOGS
    value: "image:nginx"
```


```yaml
agent:
  env: 
  - name: DD_CONTAINER_EXCLUDE # ref: https://docs.datadoghq.com/agent/guide/autodiscovery-management/?tab=containerizedagent#exclude-containers
    value: "image:docker.io/istio/proxyv2 kube_namespace:kube-system kube_namespace:istio-system kube_namespace:prometheus kube_namespace:grafana kube_namespace:kubernetes-dashboard kube_namespace:jenkins kube_namespace:kube-node-lease kube_namespace:kube-public kube_namespace:default"
  - name: DD_CONTAINER_EXCLUDE_LOGS
    value: "image:docker.io/istio/proxyv2 kube_namespace:kube-system kube_namespace:istio-system kube_namespace:prometheus kube_namespace:grafana kube_namespace:kubernetes-dashboard kube_namespace:jenkins kube_namespace:kube-node-lease kube_namespace:kube-public kube_namespace:default kube_namespace:staging-sandbox"
  - name: DD_CONTAINER_INCLUDE_LOGS # Inclusion always takes precedence. Ref: https://docs.datadoghq.com/agent/guide/autodiscovery-management/?tab=containerizedagent#inclusion-and-exclusion-behavior
    value: "image:us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler"
```


To include containers, you can use three key values:
- `DD_CONTAINER_INCLUDE`
- `DD_CONTAINER_INCLUDE_METRICS`
- `DD_CONTAINER_INCLUDE_LOGS`


And three keys:
- `name:`
- `image:`
- `kube_namespace:`


```yaml
agent:
  env: 
  .
  .
  .
  - name: DD_CONTAINER_INCLUDE_LOGS # Inclusion always takes precedence. Ref: https://docs.datadoghq.com/agent/guide/autodiscovery-management/?tab=containerizedagent#inclusion-and-exclusion-behavior
    value: "image:us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler"
```

Then upgrade
```sh
helm upgrade datadog \
  -f overrides.yaml \
  --set datadog.apiKey='YOUR_KEY' \
  datadog/datadog 
```


### 2.5.2 Include and Exclude Precedence Order
Ref: https://docs.datadoghq.com/agent/guide/autodiscovery-management/?tab=containerizedagent#inclusion-and-exclusion-behavior


__Inclusion always takes precedence__, whether the rule is global or only applies to metrics or logs.

You cannot mix cross-category include/exclude rules. For instance, if you want to include a container with the image name <IMAGE_NAME_1> and exclude only metrics from a container with the image name <IMAGE_NAME_2>, use the following:

```sh
DD_CONTAINER_INCLUDE_METRICS = "image:<IMAGE_NAME_1>"
DD_CONTAINER_INCLUDE_LOGS = "image:<IMAGE_NAME_1>"
DD_CONTAINER_EXCLUDE_METRICS = "image:<IMAGE_NAME_2>"
```


You cannot exclude a container globally (i.e. `DD_CONTAINER_EXCLUDE = "image:<IMAGE_NAME_1>"`) and then include it with container_include_logs and container_include_metrics.




## 2.6 Cluster Agent
Refs: 
- https://docs.datadoghq.com/agent/cluster_agent/
- https://www.datadoghq.com/blog/datadog-cluster-agent/?_gl=1*sdlsv5*_ga*NzE4NjU2NDg0LjE2MzEwMzg0NTg.*_ga_KN80RDFSQK*MTYzMjIzODQyOC4xNy4xLjE2MzIyMzg5MTMuMA..


### 2.6.1 Before Cluster Agent Era
Previously, every worker node in the cluster ran a Datadog Agent (__decentralized__) that collected data from two sources:
- kubelet, a local daemon that creates the workload on a node
- cluster’s control plane, which consists of the API server, the scheduler, the controller manager, and etcd

![alt text](../imgs/before_cluster_agent.jpeg "")


This led to __increased load__ for API server and etcd when more and more k8s nodes join the cluster.


### 2.6.2 After Cluster Agent Arrival

> Cluster Agent provides a streamlined, __centralized__ approach to collecting cluster level monitoring data. By acting as a __proxy__ between the API server and node-based Agents, the Cluster Agent helps to alleviate server load. It also relays cluster level metadata to node-based Agents, allowing them to enrich the metadata of locally collected metrics.

![alt text](../imgs/after_cluster_agent.jpeg "")


You can see that cluster agent pod is proxying on behalf of other datadog agent pods:

```sh
# there are 3 prod and 3 staging nodes in this cluster
$ kubectl get nodes
NAME                           STATUS   ROLES    AGE     VERSION
ip-10-1-zz-xx.ec2.internal   Ready    <none>   52d     v1.19.6-eks-49a6c0
ip-10-1-zz-xx.ec2.internal   Ready    <none>   6d10h   v1.19.13-eks-f39f26
ip-10-1-zz-xx.ec2.internal   Ready    <none>   148d    v1.19.6-eks-49a6c0
ip-10-1-zz-xx.ec2.internal   Ready    <none>   90d     v1.19.6-eks-49a6c0
ip-10-1-zz-xx.ec2.internal   Ready    <none>   25d     v1.19.13-eks-8df270
ip-10-1-zz-xx.ec2.internal   Ready    <none>   21d     v1.19.13-eks-8df270


# you can see cluster agent pods assigned for one of the three prod & staging nodes, whereas datadog agent pods are on each node
$ kubectl get pod
NAME                                               READY   STATUS    RESTARTS   AGE
datadog-prod-cluster-agent-zz-jsfn2        1/1     Running   0          44h  # <---- proxy
datadog-prod-kube-state-metrics-zz-9rxth   1/1     Running   0          44h
datadog-prod-xx                                 4/4     Running   0          44h # <--- DD agent pods on one of the three prod nodes
datadog-prod-xx                                 4/4     Running   0          44h # <--- DD agent pods on one of the three prod nodes
datadog-prod-xx                                 4/4     Running   0          44h # <--- DD agent pods on one of the three prod nodes
datadog-staging-xx                              4/4     Running   0          44h
datadog-staging-cluster-agent-zz-xx     1/1     Running   0          44h # <---- proxy
datadog-staging-kube-state-metrics-zz-xx   1/1     Running   0          6d15h
datadog-staging-xx                              4/4     Running   0          44h
datadog-staging-xx                              4/4     Running   0          44h
```

This is particularly beneficial for __large Kubernetes clusters with hundreds or even thousands of nodes__, because it significantly reduces the load on the API server, while still allowing you to surface valuable insights.


Cluster Agent can:
- Alleviate the impact of Agents on API server.
- Isolate node-based Agents to their respective nodes, reducing RBAC rules to solely read metrics and metadata from the kubelet.
- Provide __cluster level metadata that can only be found in the API server__ to the Node Agents, in order for them to enrich the metadata of the locally collected metrics.
- Enable the collection of cluster level data, such as the monitoring of services or SPOF and events.
- Leverage horizontal pod autoscaling with custom Kubernetes metrics. See the guide for more details about this feature.



### 2.6.3 Cluster Agent Setup (enabled by default)
Ref: https://docs.datadoghq.com/agent/cluster_agent/setup/?tab=helm

```yaml
clusterAgent:
  # clusterAgent.enabled -- Set this to false to disable Datadog Cluster Agent
  enabled: true
```


__Kubernetes events__ are beginning to flow into your Datadog account, and relevant metrics collected by your Agents are tagged with their corresponding cluster level metadata.



### 2.6.4 (optional) Enable Cluster Agent Custom Metrics Server for HPA (Horizontal Pod Autoscaler)
Ref: https://docs.datadoghq.com/agent/cluster_agent/external_metrics/?tab=helm

> As of Kubernetes v1.10, support for external metrics was introduced to autoscale off of any metric from outside the cluster that is collected for you by Datadog.

To enable, set `clusterAgent.metricsProvider.enabled` to true
```yaml
clusterAgent:
  enabled: true
  # Enable the metricsProvider to be able to scale based on metrics in Datadog
  metricsProvider:
    # clusterAgent.metricsProvider.enabled
    # Set this to true to enable Metrics Provider
    enabled: true
```


Example HPA yaml
- https://docs.datadoghq.com/agent/cluster_agent/external_metrics/?tab=helm#example-hpa

```yaml
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: nginxext
spec:
  minReplicas: 1
  maxReplicas: 3
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx
  metrics:
  - type: External  # <----- this
    external:
      metricName: nginx.net.request_per_s  External  # <----- this
      metricSelector:
        matchLabels:
            kube_container_name: nginx
      targetAverageValue: 9
```

Under this setting, Kubernetes queries the Datadog Cluster Agent every 30s to get the value of this metric and autoscales proportionally if necessary.
##

