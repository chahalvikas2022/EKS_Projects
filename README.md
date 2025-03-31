## Project:

Prepare a kubenates cluster from your laptop using any toolings of your choice. (k3d, minikube,
KinD, docker desktop, podman desktop, etc ...) If you prefer, you may even choose to have it
provisioned from any of the cloud providers with your personal account and apply all required
networking configurations.   

Deploy the latest argocd to this cluster through the helm
chart https://artifacthub.io/packages/helm/argo/argo-cd.
Ensure that the argocd web UI is properly exposed.
Complete the following deployments through argo-cd and gitops.
### Deployment #1  
Create an application on argocd to deploy the following docker image hello-world-api with 3 replicas
and have the service properly exposed.
https://hub.docker.com/r/nmatsui/hello-world-api
Apply some configuration to the deployed k8s resources so that the json body of the api response
contains the info of the pod id. See for example.
{
  "message": "pod-id=xxxx-xxxx-xxx-xxx"
}

### Deployment #2  
Create another application on argocd using the same docker image hello-world-api with 3 replicas
and have the service properly exposed.
https://hub.docker.com/r/nmatsui/hello-world-api
Apply some configuration to the deployed k8s resources so that the json body of the api response
contains the following additional info. See for example.
{
  "message": "pod-id=xxxx-xxxx-xxx-xxx;pod-ip=xx.xx.xx.xx;node-name=xxxxxxxxxxxxxxx"
}
### Deployment #3  
Create a third argocd application so that the argocd is able to manage and sync itself for all future
upgrades and configuration changes.


## Steps to complete the project

### Step 1 - Create an EKS cluster

  1. Create AWS account
  2. Setup AWS CLI and configure AWS and terraform on local
  3. Checkout this repo and go to 
  4. ``` cd kubernetes/EKS-ArgoCD/EKS-Code/ToDo-App ```
  5. Make changes in ToDo-App/backend.tf
  6. Create s3 bucket and DynamoDB table manually and update in backend.tf
  7. When you create DynamoDB table, name primary key as LockID. That's what terraform uses by default to lock the terraform state files
  8. Install cluster using below commands
  9. ```
     terraform init
     terraform plan
     terraform apply
     ```

### Step 2 - Login to Cluster and validate cluster

   1. Download EKS cluster kubeconfig file
   2. ``` aws eks update-kubeconfig --region <region-code> --name <cluster-name> ```
   3. Check if nodes joined the cluster using ``` kubectl get nodes ```
   4. Check if all add-ons are running ``` kubectl get pods -n kube-system ```
   5. Deploy a busybox
   6. Destory the cluster ``` terraform destroy ```
     
### Step 3 - Install ArgoCD
   1.Install Helm Chart winget install Helm.Helm
   2. Restart VSS for helm to load
   3. Add ArgoCD Helm Repository
        helm repo add argo https://argoproj.github.io/argo-helm
        helm repo update
   4. Create argocd namespace
       kubectl create namespace argocd

   5. Install ArgoCD using helm
         helm install argocd argo/argo-cd --namespace argocd
   6. Expose ArgoCD Using a LoadBalancer
       kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
   7. Get URL for ArgoCD
       kubectl get svc -n argocd
  8. Retrieve Admin password for argoCD
       kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode
  9. Login on ArgoCD - Open URL from Step 7 and put admin/password, where password coming from Step 8

Configure ArgoCD CLI (Optional)


### 4. Setup Sync with ArgoCD

#### If repo is private, below steps needs to be completed to setup connectivity, if public repo, direct sync will work

1. Generate SSH key for argocd
``` ssh-keygen -t rsa -b 4096 -C "argocd-access" -f ~/.ssh/argocd -N "" ```

This generate keys at

* ~/.ssh/argocd (private key)

* ~/.ssh/argocd.pub (public key)

2. Add the Public Key to GitHub

* Go to GitHub → Your Repo → Settings → Deploy Keys

* Click "Add deploy key", give it a name like ArgoCD Access, and paste the contents of argocd.pub.

* Check Allow write access if you want ArgoCD to push changes (usually not needed).

* Click Add key.

3. Add the Repo to ArgoCD

Run the following command to add your repo to ArgoCD:
``` argocd repo add git@github.com:aveeva-devops/projects.git --ssh-private-key-path ~/.ssh/argocd ```

If your ArgoCD instance is running inside Kubernetes, copy the private key to the ArgoCD secret:

``` kubectl create secret generic argocd-ssh-key --from-file=ssh-privatekey=/c/Users/chaha/.ssh/argocd -n argocd ```

Then patch ArgoCD to use this key:
``` kubectl patch secret argocd-ssh-key \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/ssh-known-hosts": "true"}}}' \
  -n argocd
```

### 5. Give permission to ArgoCD service Account on the cluster
If your ArgoCD instance uses RBAC, check current roles:

```
kubectl get roles -n argocd
kubectl get rolebindings -n argocd
```

If your user is not assigned to an admin role, create a new RoleBinding:
```
kubectl create clusterrolebinding argocd-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=argocd:argocd-application-controller
```

### 6. Project 1 
Create an application on argocd to deploy the following docker image hello-world-api with 3 replicas
and have the service properly exposed.
https://hub.docker.com/r/nmatsui/hello-world-api
Apply some configuration to the deployed k8s resources so that the json body of the api response
contains the info of the pod id. See for example.
{
  "message": "pod-id=xxxx-xxxx-xxx-xxx"
}

### Solution for Project 1

#### Create application1.yaml as below:

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-world-api-pod-id
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:aveeva-devops/projects.git
    targetRevision: HEAD
    path: kubernetes/EKS-ArgoCD/app1
  destination: 
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    automated:
      selfHeal: true
      prune: true

```

#### Create respective application deployment files:
```
apiVersion: v1
kind: Namespace
metadata:
  name: podid
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-api
  namespace: podid
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-world-api
  template:
    metadata:
      labels:
        app: hello-world-api
    spec:
      containers:
      - name: hello-world-api
        image: nmatsui/hello-world-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: POD_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name  # Injects Pod Name as POD_ID
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Starting API with POD_ID=$POD_ID";
          exec node -e "
          const http = require('http');
          const server = http.createServer((req, res) => {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ message: 'pod-id=' + process.env.POD_ID }));
          });
          server.listen(3000);
          console.log('Server running on port 3000');"
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world-api
  namespace: podid
spec:
  selector:
    app: hello-world-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer

```

#### Apply application file 

``` kubectl apply -f application1.yaml ```

This will deploy the application via ArgoCD 

Check services in podid namespace and validate the output

``` kubectl get svc -n podid ```

Validate service output 

``` curl http://service_endpoint ```

### 7. Project 2  
Create another application on argocd using the same docker image hello-world-api with 3 replicas
and have the service properly exposed.
https://hub.docker.com/r/nmatsui/hello-world-api
Apply some configuration to the deployed k8s resources so that the json body of the api response
contains the following additional info. See for example.
{
  "message": "pod-id=xxxx-xxxx-xxx-xxx;pod-ip=xx.xx.xx.xx;node-name=xxxxxxxxxxxxxxx"
}

### Solution for Project 2

#### Create application2.yaml as below:

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-world-api-pod-node-id
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:aveeva-devops/projects.git
    targetRevision: HEAD
    path: kubernetes/EKS-ArgoCD/app2
  destination: 
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    automated:
      selfHeal: true
      prune: true

```

#### Create respective application deployment files in app2 folder:
```
apiVersion: v1
kind: Namespace
metadata:
  name: nodeid
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-api
  namespace: nodeid
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world-api
  template:
    metadata:
      labels:
        app: hello-world-api
    spec:
      containers:
      - name: hello-world-api
        image: nmatsui/hello-world-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: POD_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name  # Gets Pod Name
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP  # Gets Pod IP
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName  # Gets Node Name
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Starting API with POD_ID=$POD_ID, POD_IP=$POD_IP, NODE_NAME=$NODE_NAME";
          exec node -e "
          const http = require('http');
          const server = http.createServer((req, res) => {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
              message: 'pod-id=' + process.env.POD_ID +
                       ';pod-ip=' + process.env.POD_IP +
                       ';node-name=' + process.env.NODE_NAME
            }));
          });
          server.listen(3000);
          console.log('Server running on port 3000');"
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world-api
  namespace: nodeid
spec:
  selector:
    app: hello-world-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer

```

#### Apply application file 

``` kubectl apply -f application2.yaml ```

This will deploy the application via ArgoCD 

Check services in podid namespace and validate the output

``` kubectl get svc -n nodeid ```

Validate service output 

``` curl http://service_endpoint ```

### 8. Project 3
Create a third argocd application so that the argocd is able to manage and sync itself for all future
upgrades and configuration changes. 

### Solution for Project 3

Change replicas of any of above 2 manifests files and commit to validate if autosync is happening
