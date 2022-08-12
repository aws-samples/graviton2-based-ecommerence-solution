#!/bin/bash -xe
set -x

function exportParams() {
    subnet1=`grep 'Subnet1ID' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    subnet2=`grep 'Subnet2ID' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    publicsubnet1=`grep 'PublicSubnet1' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    publicsubnet2=`grep 'PublicSubnet2' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    eksname=`grep 'EKSName' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    eksnodetype=`grep 'EKSNodeType' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    eksnodes=`grep 'EKSNodes' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    dbhost=`grep 'DBEndPointAddress' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    dbuser=`grep 'DBMasterUsername' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    dbpassword=`grep 'DBMasterUserPassword' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    dbname=`grep 'DBName' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    adminpassword=`grep 'AdminPassword' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    cachehost=`grep 'ElastiCacheEndpoint' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    efsid=`grep 'FileSystem' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    spot=`grep 'SpotNodeGroup' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    vpcid=`grep 'VPCID' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
    key=`grep 'KeyPair' ${PARAMS_FILE} | awk -F'|' '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
}


PARAMS_FILE=/tmp/params.txt

subnet1='NONE'
subnet2='NONE'
publicsubnet1='NONE'
publicsubnet2='NONE'
eksname='NONE'
eksnodetype='NONE'
eksnodes='NONE'
dbhost='NONE'
dbuser='NONE'
dbpassword='NONE'
dbname='NONE'
adminpassword='NONE'
cachehost='NONE'
efsid='NONE'
spot='NONE'
vpcid='NONE'
key='NONE'

exportParams


EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"


yum -y update
yum -y install jq

curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/arm64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
kubectl version --short --client


curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/v0.95.0/eksctl_Linux_armv6.tar.gz" | tar xz -C /tmp
cp /tmp/eksctl $HOME/bin/eksctl && export PATH=$PATH:$HOME/bin
eksctl version

cat << EOF > /home/ec2-user/cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $eksname
  region: $EC2_REGION

vpc:
  id: "$vpcid"
  subnets:
    private:
      private-one:
          id: "$subnet1"
      private-two:
          id: "$subnet2"
    public:
      public-one:
          id: "$publicsubnet1"
      public-two:
          id: "$publicsubnet2"

managedNodeGroups:
  - name: ng-onDemand
    spot: $spot
    instanceType: $eksnodetype
    desiredCapacity: $eksnodes
    minSize: 1
    maxSize: 10
    privateNetworking: true
    ssh:
      publicKeyName: '$key'
      enableSsm: true
    subnets:
      - private-one
      - private-two
EOF

eksctl create cluster -f /home/ec2-user/cluster.yaml

kubectl get nodes


curl -o csidriver.yaml https://awspsa-quickstart.s3.cn-northwest-1.amazonaws.com.cn/awspsa-odoo/scripts/csidriver.yaml
curl -o node.yaml https://awspsa-quickstart.s3.cn-northwest-1.amazonaws.com.cn/awspsa-odoo/scripts/node.yaml
curl -o kustomization.yaml https://awspsa-quickstart.s3.cn-northwest-1.amazonaws.com.cn/awspsa-odoo/scripts/kustomization.yaml

kubectl apply -k ./


cat << EOF > ./odoo-arm-efs-s3-redis.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: odoo
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-pvc
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: $efsid
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-storage-claim
  namespace: odoo
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: odoo-arm
  namespace: odoo
  labels:
    app: odoo-arm
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  ports:
    - port: 80
      protocol: TCP
      targetPort: 8069
  selector:
    app: odoo-arm
    tier: frontend
  type: LoadBalancer
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: odoo-config
  namespace: odoo
data:
  odoo.conf: |-
    [options]
    admin_passwd = $adminpassword
    addons_path = /mnt/extra-addons
    data_dir = /var/lib/odoo
    proxy_mode = True
    db_host = $dbhost
    db_port = 5432
    db_name = odoo
    db_user = $dbuser
    db_password = $dbpassword
    server_wide_modules = base,web,smile_redis_session_store
    enable_redis = True
    redis_host = $cachehost
    redis_port = 6379
    redis_dbindex = 1
    max_cron_threads = 4
    logrotate = False
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: odoo-arm
  namespace: odoo
  labels:
    app: odoo-arm
spec:
  replicas: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: odoo-arm
  template:
    metadata:
      labels:
        app: odoo-arm
        tier: frontend
    spec:
      containers:
        - image: wujiade/odoo-graviton2:v5
          name: odoo-arm
          securityContext:
            privileged: true
            runAsUser: 0
          ports:
            - containerPort: 8069
              name: odoo
          resources:
              requests:
                cpu: 600m
                memory: 1500Mi
          volumeMounts:
          - name: efs-pvc
            mountPath: /var/lib/odoo
          - name: config-volume
            mountPath: "/etc/odoo/"
      volumes:
      - name: efs-pvc
        persistentVolumeClaim:
          claimName: efs-storage-claim
      - name: config-volume
        configMap:
          name: odoo-config
      nodeSelector:
        kubernetes.io/arch: arm64
EOF


kubectl apply -f ./odoo-arm-efs-s3-redis.yaml

sleep 10

kubectl get svc -n odoo -o=json | jq -r '.items[].status.loadBalancer.ingress[].hostname'
ODOO_URL=`kubectl get svc -n odoo -o=json | jq -r '.items[].status.loadBalancer.ingress[].hostname'`


kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.7/components.yaml

sleep 10
kubectl apply -f https://awspsa-quickstart.s3.cn-northwest-1.amazonaws.com.cn/awspsa-odoo/scripts/recommended.yaml
sleep 10


cat << EOF > dashboard-access.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

kubectl apply -f dashboard-access.yaml
sleep 10

kubectl get svc kubernetes-dashboard -n kubernetes-dashboard -o=json | jq -r '.status.loadBalancer.ingress[].hostname' 
DASHBOARD_URL=`kubectl get svc kubernetes-dashboard -n kubernetes-dashboard -o=json | jq -r '.status.loadBalancer.ingress[].hostname'` 

cat << EOF > /home/ec2-user/outputurl
Odoo_URL[http://$ODOO_URL]Kubernetes_dashboard[https://$DASHBOARD_URL]
EOF

yum -y install make gcc-c++ cmake bison-devel ncurses-devel libaio

wget -P /home/ec2-user/ http://download.joedog.org/siege/siege-4.0.4.tar.gz
tar -zvxf /home/ec2-user/siege-4.0.4.tar.gz
cd siege-4.0.4/
./configure
make && make install
