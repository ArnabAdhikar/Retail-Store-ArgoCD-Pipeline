# =============================================================================
# OUTPUT VALUES
# =============================================================================

# =============================================================================
# CLUSTER INFORMATION
# =============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster (with unique suffix)"
  value       = module.retail_app_eks.cluster_name
}

output "cluster_name_base" {
  description = "Base cluster name without suffix"
  value       = var.cluster_name
}

output "cluster_name_suffix" {
  description = "Random suffix added to cluster name"
  value       = random_string.suffix.result
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.retail_app_eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.retail_app_eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.retail_app_eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.retail_app_eks.cluster_oidc_issuer_url
}

# =============================================================================
# NETWORK INFORMATION
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# =============================================================================
# ACCESS INFORMATION
# =============================================================================

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.retail_app_eks.cluster_name}"
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.argocd_namespace
}

output "argocd_server_port_forward" {
  description = "Command to port-forward to ArgoCD server"
  value       = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:443"
}

output "argocd_admin_password" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = true
}

# =============================================================================
# APPLICATION ACCESS
# =============================================================================

output "ingress_nginx_loadbalancer" {
  description = "Command to get the LoadBalancer URL for accessing applications"
  value       = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "retail_store_url" {
  description = "Command to get the retail store application URL"
  value       = "echo 'http://'$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
}

# =============================================================================
# USEFUL COMMANDS
# =============================================================================

output "useful_commands" {
  description = "Useful commands for managing the cluster"
  value = {
    get_nodes           = "kubectl get nodes"
    get_pods_all        = "kubectl get pods -A"
    get_retail_store    = "kubectl get pods -n retail-store"
    argocd_apps         = "kubectl get applications -n ${var.argocd_namespace}"
    ingress_status      = "kubectl get ingress -A"
    describe_cluster    = "kubectl cluster-info"
  }
}

# =============================================================================
# GITOPS IAM USER OUTPUTS
# =============================================================================

output "gitops_user_arn" {
  description = "ARN of the dedicated GitOps IAM user"
  value       = aws_iam_user.gitops_user.arn
}

output "gitops_user_name" {
  description = "Name of the dedicated GitOps IAM user"
  value       = aws_iam_user.gitops_user.name
}

output "gitops_access_key_id" {
  description = "AWS Access Key ID for the GitOps user — add this as GitHub Secret AWS_ACCESS_KEY_ID"
  value       = aws_iam_access_key.gitops_user_key.id
  sensitive   = true
}

output "gitops_secret_access_key" {
  description = "AWS Secret Access Key for the GitOps user — add this as GitHub Secret AWS_SECRET_ACCESS_KEY. TREAT AS SENSITIVE."
  value       = aws_iam_access_key.gitops_user_key.secret
  sensitive   = true
}

output "gitops_retrieve_credentials_commands" {
  description = "Commands to retrieve GitOps credentials from SSM (use these to populate GitHub Secrets)"
  value = {
    get_access_key_id     = "aws ssm get-parameter --name /gitops/cicd/access-key-id --with-decryption --query Parameter.Value --output text"
    get_secret_access_key = "aws ssm get-parameter --name /gitops/cicd/secret-access-key --with-decryption --query Parameter.Value --output text"
    set_github_secret_id  = "gh secret set AWS_ACCESS_KEY_ID --body \"$(aws ssm get-parameter --name /gitops/cicd/access-key-id --with-decryption --query Parameter.Value --output text)\""
    set_github_secret_key = "gh secret set AWS_SECRET_ACCESS_KEY --body \"$(aws ssm get-parameter --name /gitops/cicd/secret-access-key --with-decryption --query Parameter.Value --output text)\""
  }
}

output "gitops_attached_policies" {
  description = "List of IAM policies attached to the GitOps group"
  value = {
    ecr_policy        = aws_iam_policy.ecr_policy.arn
    eks_policy        = aws_iam_policy.eks_policy.arn
    kms_policy        = aws_iam_policy.kms_policy.arn
    elb_vpc_policy    = aws_iam_policy.elb_vpc_readonly_policy.arn
    ssm_policy        = aws_iam_policy.ssm_readonly_policy.arn
    deny_guardrail    = aws_iam_policy.gitops_deny_policy.arn
  }
}
