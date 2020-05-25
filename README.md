# AWS Credential Updater

Small helper script that, given a set of AWS credentials,  periodically (every 11 1/2 hours) fetches
a Docker ECR login and updates that to a Kubernetes secret in a list of namespaces.

The idea is that an ECR docker login, which is relatively short lived (12 hours), can be kept up to
date using an AWS service account IAM user that is slightly longer lived (eg. several weeks).

In addition, this helper script can act as a "multiplier", by making AWS account credentials
available in a single namespace (potentially a restricted namespace such as kube-system)
and planting registry credentials in multiple namespaces. This way, a single configmap can be
updated by the owner of the AWS account (or even by a Lamda function) without the AWS account
owner needing to know all the namespaces that pull container images from ECR.

It goes without saying that you do NOT need this if your Kubernetes cluster is running inside AWS
(either in EKS or in an EC2 instance). In that case, there are better ways to do this using IAM roles.
This little helper is intended for clusters that run outside of AWS.


## Usage

This script is intended to run in-cluster, in Kubernetes manifest such as the following:

```
###
### RBAC
###
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-ecr-cred-helper
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aws-ecr-cred-helper
rules:
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - get
      - patch
      - watch
      - list
    resourceNames:
      # The name specified here MUST match the SECRET_NAME specified in the helper config"
      - registry-aws-ecr

  # It seems that verb "create" does not work in combination with resourceNames. But, at least,
  # this prevents us from reading or modifying any other secrets.
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aws-ecr-cred-helper
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: aws-ecr-cred-helper
subjects:
- kind: ServiceAccount
  name: aws-ecr-cred-helper
  namespace: kube-system


###
### Helper configuration
###
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-ecr-cred-helper-config
  namespace: kube-system
type: Opaque
data:
  # The following values are actual sample values.
  # "NAMESPACES" is base64 encoded for "kube-system default", and
  # "SECRET_NAME" is base64 encoded for "registry-aws-ecr" and MUST MATCH the resourceName
  #   specified in the RBAC rule above.
  NAMESPACES: a3ViZS1zeXN0ZW0gZGVmYXVsdA==      # List of namespaces, space separated, BASE64 ENCODED
  SECRET_NAME: cmVnaXN0cnktYXdzLWVjcg==         # Name of the K8s secret to update
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-ecr-cred-helper-config-aws
  namespace: kube-system
type: Opaque
data:
  # Following values are placeholders - replace with your own credentials
  AWS_ACCESS_KEY_ID: UGxhY2Vob2xkZXIuLi4K       # Your AWS access key ID, BASE64 ENCODED
  AWS_SECRET_ACCESS_KEY: UGxhY2Vob2xkZXIuLi4K   # Your AWS Secret Acces Key, BASE64 ENCODED
  AWS_DEFAULT_REGION: UGxhY2Vob2xkZXIuLi4K      # Your AWS region, BASE64 encoded

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-ecr-cred-helper
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: aws-ecr-cred-helper
  replicas: 1
  template:
    metadata:
      labels:
        app: aws-ecr-cred-helper
    spec:
      containers:
        - name: aws-ecr-cred-helper
          imagePullPolicy: Always
          image: ckoester/aws-ecr-cred-helper
          volumeMounts:
            - name: aws-ecr-cred-helper-config
              mountPath: /config
              readOnly: true
            - name: aws-ecr-cred-helper-config-aws
              mountPath: /config-aws
              readOnly: true
      serviceAccountName: aws-ecr-cred-helper
      securityContext:
        fsGroup: 1000
      volumes:
        - name: aws-ecr-cred-helper-config
          secret:
            secretName: aws-ecr-cred-helper-config
            defaultMode: 0o0640
        - name: aws-ecr-cred-helper-config-aws
          secret:
            secretName: aws-ecr-cred-helper-config-aws
            defaultMode: 0o0640
```
