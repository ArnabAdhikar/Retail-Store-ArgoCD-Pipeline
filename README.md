# 🛒 Retail Store ArgoCD GitOps Pipeline

A production-grade **GitOps CI/CD pipeline** for a microservices-based retail store application, deployed on **Amazon EKS** using **ArgoCD**, **GitHub Actions**, **Terraform**, and **NGINX Ingress** with automatic SSL via **cert-manager**.

> **Live Application:** [https://retail-store.arnaba075.com](https://retail-store.arnaba075.com)

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Branch Strategy](#branch-strategy)
- [Prerequisites](#prerequisites)
- [Infrastructure Setup (Terraform)](#infrastructure-setup-terraform)
- [GitOps Pipeline (GitHub Actions)](#gitops-pipeline-github-actions)
- [Custom Domain & SSL Setup](#custom-domain--ssl-setup)
- [ArgoCD Configuration](#argocd-configuration)
- [IAM Security (Least Privilege)](#iam-security-least-privilege)
- [Troubleshooting & Problems Fixed](#troubleshooting--problems-fixed)
- [Cleanup](#cleanup)

---

## 🏗️ Architecture Overview

```
Developer Push (src/)
        │
        ▼
┌─────────────────────┐
│   GitHub Actions     │  ← Triggered on push to gitops branch
│   (gitops branch)    │
└────────┬────────────┘
         │
    ┌────▼─────────────────────────────────┐
    │  1. Detect changed services          │
    │  2. Build Docker image               │
    │  3. Push to private ECR              │
    │  4. Update Helm values.yaml (tag)    │
    │  5. Commit back to gitops branch     │
    └────────────────┬─────────────────────┘
                     │
                     ▼
         ┌───────────────────┐
         │      ArgoCD       │  ← Watches gitops branch
         │  (in-cluster)     │
         └────────┬──────────┘
                  │ Auto-sync
                  ▼
      ┌───────────────────────┐
      │   Amazon EKS Cluster  │
      │   (us-west-1)         │
      │                       │
      │  ┌─────────────────┐  │
      │  │  retail-store   │  │
      │  │  namespace      │  │
      │  │  ┌───┐ ┌─────┐  │  │
      │  │  │ ui│ │catalog│  │  │
      │  │  ├───┤ ├─────┤  │  │
      │  │  │cart│ │orders│  │  │
      │  │  └───┘ └─────┘  │  │
      │  └─────────────────┘  │
      │                       │
      │  NGINX Ingress ──────────► retail-store.arnaba075.com
      │  cert-manager (HTTPS)     (Route53 → NLB → Ingress)
      └───────────────────────┘
```

### Technology Stack

| Component | Technology |
|---|---|
| **Cloud Provider** | AWS (us-west-1) |
| **Kubernetes** | Amazon EKS v1.33 |
| **Infrastructure as Code** | Terraform |
| **GitOps Operator** | ArgoCD |
| **CI/CD Pipeline** | GitHub Actions |
| **Container Registry** | Amazon ECR (private) |
| **Ingress Controller** | NGINX |
| **Certificate Manager** | cert-manager (Let's Encrypt) |
| **DNS** | AWS Route53 |
| **Package Manager** | Helm |

---

## 🌿 Branch Strategy

This repository uses a **dual-branch GitOps strategy**:

| Feature | `main` branch | `gitops` branch |
|---|---|---|
| **Purpose** | Public demo / simple deploy | Production / automated CI/CD |
| **Images** | Public ECR (stable v1.2.2) | Private ECR (auto-tagged) |
| **GitHub Actions** | ❌ None | ✅ Full CI/CD pipeline |
| **ArgoCD Target** | Umbrella chart | Individual service apps |
| **Updates** | Manual | Automatic on code push |

> **Key Rule:** The `.github/workflows/` directory exists **only** on the `gitops` branch. It must never be merged into `main`.

---

## ✅ Prerequisites

| Tool | Version | Install |
|---|---|---|
| **AWS CLI** | v2+ | [Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| **Terraform** | 1.0+ | [Guide](https://developer.hashicorp.com/terraform/install) |
| **kubectl** | 1.33+ | [Guide](https://kubernetes.io/docs/tasks/tools/) |
| **Docker** | 20.0+ | [Guide](https://docs.docker.com/get-docker/) |
| **Helm** | 3.0+ | [Guide](https://helm.sh/docs/intro/install/) |
| **Git** | 2.0+ | [Guide](https://git-scm.com/downloads) |

<details>
<summary><strong>🔧 One-Click Installation (Ubuntu/Debian)</strong></summary>

```bash
#!/bin/bash

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
aws --version && terraform --version && kubectl version --client && docker --version && helm version
```
</details>

---

## 🚀 Infrastructure Setup (Terraform)

### Step 1: Configure AWS Credentials

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-west-1), Output format (json)
```

### Step 2: Clone the Repository

```bash
git clone https://github.com/ArnabAdhikar/Retail-Store-ArgoCD-Pipeline.git
cd Retail-Store-ArgoCD-Pipeline
git checkout gitops
```

### Step 3: Deploy Core Infrastructure

```bash
cd terraform
terraform init
terraform plan    # Review changes
terraform apply   # Type 'yes' to confirm
```

This provisions:
- **VPC** with public and private subnets across 2 AZs
- **Amazon EKS cluster** (`retail-store-tnoh`) with Kubernetes v1.33
- **Node groups** with managed auto-scaling
- **NGINX Ingress Controller** (exposed via AWS NLB)
- **cert-manager** for automatic SSL certificates
- **ArgoCD** installed via Helm
- **IAM GitOps user** with least-privilege policies
- **SSM Parameters** storing GitOps credentials

> ⏱️ Infrastructure provisioning takes approximately **15-20 minutes**.

### Step 4: Connect kubectl to the Cluster

```bash
# Command is also available in terraform output
aws eks update-kubeconfig --region us-west-1 --name retail-store-tnoh

# Verify connectivity
kubectl get nodes
kubectl get pods -A
```

---

## ⚙️ GitOps Pipeline (GitHub Actions)

The CI/CD pipeline lives in `.github/workflows/deploy.yml` on the `gitops` branch.

### Pipeline Trigger

Pushes to the `gitops` branch that modify files under `src/**` automatically trigger the workflow. It can also be run manually via `workflow_dispatch`.

### Pipeline Steps

```
1. detect-changes  → Compares HEAD~1 vs HEAD to find changed services
2. deploy          → For each changed service (parallel matrix):
   a. Configure AWS credentials
   b. Login to ECR
   c. Create ECR repo if it doesn't exist
   d. Build Docker image (tagged with 7-char commit SHA)
   e. Push image to ECR
   f. Update src/<service>/chart/values.yaml with new image tag
   g. Commit and push the updated Helm values back to gitops branch
3. summary         → Post deployment summary to GitHub Actions UI
```

### Step 5: Configure GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions** and add:

| Secret | Description | Example |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | GitOps IAM user access key | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | GitOps IAM user secret key | `wJalr...` |
| `AWS_REGION` | AWS region | `us-west-1` |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID | `356302822804` |

### Retrieve Credentials from SSM (created by Terraform)

```bash
# Get Access Key ID
aws ssm get-parameter --name /gitops/cicd/access-key-id --with-decryption \
  --query Parameter.Value --output text

# Get Secret Access Key
aws ssm get-parameter --name /gitops/cicd/secret-access-key --with-decryption \
  --query Parameter.Value --output text
```

### Step 6: Trigger a Deployment

```bash
git checkout gitops

# Make a change to any service
echo "// trigger rebuild" >> src/ui/src/main/resources/static/app.js

git add . && git commit -m "feat: trigger pipeline"
git push origin gitops
```

> ⚠️ **Important:** Use your **Personal Access Token (PAT)** as the password when pushing. GitHub deprecated password-based Git authentication. Generate one at [github.com/settings/tokens](https://github.com/settings/tokens) with the `repo` scope.

### Handling Push Rejections (Non-Fast-Forward)

The pipeline auto-commits image tag updates back to the `gitops` branch. If your push is rejected, always run:

```bash
git pull origin gitops --rebase
git push origin gitops
```

---

## 🌐 Custom Domain & SSL Setup

### Step 7: Configure Route53 DNS

The file `terraform/dns.tf` manages DNS automatically. It:
1. Fetches your existing Route53 hosted zone for `arnaba075.com`
2. Waits 60 seconds for the NLB to be provisioned
3. Creates a `CNAME` record: `retail-store.arnaba075.com` → NLB hostname

Apply DNS configuration:
```bash
cd terraform
terraform apply   # Only needs to run once after cluster creation
```

> ⚠️ **Hostname Naming Rule:** DNS hostnames must follow **RFC 1123** — only lowercase letters, numbers, hyphens (`-`), and dots (`.`). **Underscores are not allowed.** Use `retail-store` not `retail_store`.

### Step 8: Verify DNS Propagation

Query the authoritative Route53 nameserver directly (bypasses caching):
```bash
nslookup retail-store.arnaba075.com ns-1994.awsdns-57.co.uk
```

Full propagation to public resolvers (Google, Cloudflare) takes **2-5 minutes**.

### SSL Certificate (Automatic)

`cert-manager` automatically:
1. Detects the Ingress with the `cert-manager.io/cluster-issuer: letsencrypt-prod` annotation
2. Creates an `HTTP-01` challenge
3. Requests the certificate from Let's Encrypt
4. Stores the certificate in the `tls-secret` Kubernetes Secret

Monitor certificate issuance:
```bash
kubectl get certificate -n retail-store
kubectl describe certificate tls-secret -n retail-store
```

---

## 🔄 ArgoCD Configuration

### ArgoCD Applications

Individual service applications are defined in `argocd/applications/`:

| Application | Helm Chart Path | Target Branch |
|---|---|---|
| `retail-store-ui` | `src/ui/chart` | `gitops` |
| `retail-store-catalog` | `src/catalog/chart` | `gitops` |
| `retail-store-cart` | `src/cart/chart` | `gitops` |
| `retail-store-checkout` | `src/checkout/chart` | `gitops` |
| `retail-store-orders` | `src/orders/chart` | `gitops` |

### Step 9: Access ArgoCD UI

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open: [https://localhost:8080](https://localhost:8080)  
Username: `admin`  
Password: *(from command above)*

### Useful ArgoCD Commands

```bash
# Check all application statuses
kubectl get applications -n argocd

# Force a hard refresh (re-reads GitHub)
kubectl annotate application retail-store-ui -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# Force a manual sync
kubectl patch application retail-store-ui -n argocd \
  --type merge -p '{"operation":{"sync":{"prune":true}}}'

# Check sync error details
kubectl get application retail-store-ui -n argocd \
  -o jsonpath='{.status.conditions}' | python3 -m json.tool
```

---

## 🔒 IAM Security (Least Privilege)

The `gitops-cicd-user` is provisioned by Terraform (`terraform/iam_gitops_user.tf`) with **scoped, minimal permissions**:

| Policy | Scope | Purpose |
|---|---|---|
| **ECR** | `retail-store-*` repos only | Build & push Docker images |
| **EKS** | `retail-store` cluster only | Read cluster info for kubeconfig |
| **KMS** | Cluster encryption key only | Decrypt ECR images |
| **ELB/VPC** | Read-only | Health checks |
| **SSM** | `/gitops/*` path only | Read stored credentials |
| **DENY guardrail** | All resources | Block destructive actions (IAM changes, cluster deletion, etc.) |

> The `DENY` policy is attached directly to the **user** (not the group) so it cannot be bypassed by changing group membership.

---

## 🐛 Troubleshooting & Problems Fixed

This section documents every real issue encountered during implementation and how it was resolved.

---

### ❌ Problem 1: GitHub Password Authentication Rejected

**Error:**
```
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/...'
```

**Root Cause:** GitHub deprecated password-based authentication for Git CLI operations.

**Fix:** Generate a **Personal Access Token (PAT)**:
1. Go to [github.com/settings/tokens](https://github.com/settings/tokens) → Generate new token (classic)
2. Select the `repo` scope
3. Use the token as your password when running `git push`

**Save the token permanently:**
```bash
git config --global credential.helper store
# Next push will save the token automatically
```

---

### ❌ Problem 2: `.github` Directory Visible on Wrong Branch

**Problem:** The `.github/workflows/` directory was present on both `main` and `gitops` branches, but it should only exist on `gitops`.

**Fix:**
```bash
git checkout main
rm -rf .github
git add .github
git commit -m "Remove .github directory from main branch"
git push origin main
```

After a subsequent merge from `main` into `gitops` removed `.github` from `gitops`, we restored it:
```bash
git checkout gitops
git checkout a2bf882 -- .github  # Restore from a specific commit
git commit -m "Restore .github directory to gitops branch"
```

---

### ❌ Problem 3: Push Rejected (Non-Fast-Forward)

**Error:**
```
! [rejected] gitops -> gitops (non-fast-forward)
hint: Updates were rejected because the tip of your current branch is behind
```

**Root Cause:** The GitHub Actions pipeline auto-commits Helm value updates (image tags) to the `gitops` branch while you're working locally. Your local branch falls behind.

**Fix:** Always pull with rebase before pushing:
```bash
git pull origin gitops --rebase
git push origin gitops
```

---

### ❌ Problem 4: ArgoCD Applications Pointing to Wrong Branch

**Problem:** After setting up individual ArgoCD applications in `argocd/applications/`, they had `targetRevision: main` but needed to read the updated Helm values from the `gitops` branch.

**Fix:**
```bash
sed -i 's/targetRevision: main/targetRevision: gitops/g' argocd/applications/*.yaml
git add argocd/applications/ && git commit -m "Update ArgoCD to track gitops branch"
```

---

### ❌ Problem 5: Terraform DNS Error — `Attempt to index null value`

**Error:**
```hcl
Error: Attempt to index null value
  on dns.tf line 29, in resource "aws_route53_record" "retail_store":
  records = [data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname]
```

**Root Cause:** The AWS NLB takes 1-2 minutes to be assigned a hostname after EKS addon provisioning. Terraform tried to read it before it was available.

**Fix in `terraform/dns.tf`:**
```hcl
# Added a 60-second wait after addons are ready
resource "time_sleep" "wait_for_lb" {
  create_duration = "60s"
  depends_on      = [module.eks_addons]
}

# Use kubernetes_service_v1 (not deprecated kubernetes_service)
data "kubernetes_service_v1" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [time_sleep.wait_for_lb]
}

# Use try() to handle cases where hostname isn't available yet
records = [
  try(data.kubernetes_service_v1.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname, "pending.arnaba075.com")
]
```

---

### ❌ Problem 6: Invalid Hostname — Underscore in Domain Name

**Error from ArgoCD:**
```
Ingress.networking.k8s.io "retail-store-ui-domain" is invalid:
spec.rules[0].host: Invalid value: "retail_store.arnaba075.com":
a lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.'
```

**Root Cause:** Underscores (`_`) are **not valid** in DNS hostnames per RFC 1123. Kubernetes enforces this strictly at the Ingress level.

**Fix:** Rename the subdomain from `retail_store` to `retail-store` everywhere:
```bash
# Fix values.yaml
sed -i 's/retail_store\.arnaba075\.com/retail-store.arnaba075.com/g' src/ui/chart/values.yaml

# Fix dns.tf
sed -i 's/retail_store\.arnaba075\.com/retail-store.arnaba075.com/g' terraform/dns.tf

git add . && git commit -m "Fix hostname: use hyphen instead of underscore (RFC 1123)"
```

---

### ❌ Problem 7: Helm Chart Error — `Cannot set both ingress.enabled and ingresses`

**Error from ArgoCD manifest generation:**
```
Error: execution error at (retail-store-sample-ui-chart/templates/ingress.yaml):
Cannot set both ingress.enabled and ingresses
```

**Root Cause:** The UI Helm chart's `ingress.yaml` template prohibits enabling both the global `ingress.enabled: true` flag **and** the `ingresses` list simultaneously.

**Fix in `src/ui/chart/values.yaml`:**
```yaml
# WRONG - causes conflict
ingress:
  enabled: true   # ← Cannot be true when 'ingresses' list is also configured

# CORRECT - use the ingresses list only
ingress:
  enabled: false  # ← Keep false; domain config goes in 'ingresses' list

ingresses:
  - name: domain
    hosts:
      - retail-store.arnaba075.com
```

---

### ❌ Problem 8: ArgoCD Stuck in `Unknown` Sync Status

**Problem:** `kubectl get application retail-store-ui -n argocd` showed `Unknown` sync status. Hard refreshes and patches appeared to have no effect.

**Root Cause:** ArgoCD had a cached `ComparisonError` from the previous invalid hostname error (Problem 6). It would not attempt to re-sync until the cache was cleared.

**Fix — Two-step force:**
```bash
# 1. Force a hard refresh (clears ArgoCD's manifest cache from GitHub)
kubectl annotate application retail-store-ui -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# 2. Trigger a forced sync operation
kubectl patch application retail-store-ui -n argocd \
  --type merge -p '{"operation":{"sync":{"prune":true,"syncOptions":["Force=true"]}}}'
```

---

### ❌ Problem 9: Route53 CNAME Pointing to `pending.arnaba075.com`

**Problem:** `nslookup retail-store.arnaba075.com` returned `NXDOMAIN`, but the Route53 console showed the record existed — pointing to `pending.arnaba075.com` (the `try()` fallback value from Problem 5's fix).

**Root Cause:** The `lifecycle { ignore_changes = [] }` block in `dns.tf` prevented Terraform from updating the record value on subsequent `apply` runs.

**Fix — Directly update the Route53 record via AWS CLI:**
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_HOSTED_ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "retail-store.arnaba075.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<NLB_HOSTNAME>"}]
      }
    }]
  }'
```

Get your NLB hostname:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

### ❌ Problem 10: `nslookup` Returns NXDOMAIN Even After Route53 Update

**Problem:** `nslookup retail-store.arnaba075.com 8.8.8.8` returned `NXDOMAIN` even though the Route53 record was correctly set.

**Root Cause:** External DNS resolvers (Google's `8.8.8.8`, Cloudflare's `1.1.1.1`) have their own propagation timelines and may serve stale/cached responses.

**Verification — Query the authoritative nameserver directly:**
```bash
# Bypass all external caching by going straight to Route53's authoritative NS
nslookup retail-store.arnaba075.com ns-1994.awsdns-57.co.uk
```

If this resolves correctly, the DNS is properly configured — just wait 2-5 minutes for global propagation.

---

## 🗑️ Cleanup

To destroy all AWS resources:

```bash
cd terraform
terraform destroy
# Type 'yes' to confirm
```

> ⚠️ **Manual cleanup required:** ECR repositories must be deleted manually from the AWS Console (Terraform won't delete repositories that contain images by default).

---

## 📊 Quick Reference Commands

```bash
# Cluster access
aws eks update-kubeconfig --region us-west-1 --name retail-store-tnoh

# Check everything
kubectl get pods -A
kubectl get ingress -A
kubectl get applications -n argocd
kubectl get certificate -n retail-store

# ArgoCD UI access
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get Load Balancer URL
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check GitHub Actions secrets via SSM
aws ssm get-parameter --name /gitops/cicd/access-key-id \
  --with-decryption --query Parameter.Value --output text

# Force ArgoCD to re-read GitHub
kubectl annotate application retail-store-ui -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# Verify DNS from authoritative nameserver
nslookup retail-store.arnaba075.com ns-1994.awsdns-57.co.uk
```

---

<div align="center">

**Built with ❤️ using AWS EKS, ArgoCD, GitHub Actions, and Terraform**

**⭐ Star this repository if you found it helpful!**

</div>
