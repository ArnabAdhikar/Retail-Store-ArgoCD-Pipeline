# =============================================================================
# IAM GITOPS USER - Dedicated user for GitOps CI/CD pipeline
# Principle of Least Privilege: only the exact permissions required
# =============================================================================

# -----------------------------------------------------------------------------
# 1. IAM USER
# -----------------------------------------------------------------------------
resource "aws_iam_user" "gitops_user" {
  name = "gitops-cicd-user"
  path = "/gitops/"

  tags = merge(local.common_tags, {
    Name        = "gitops-cicd-user"
    Purpose     = "GitOps CI/CD pipeline automation"
    ManagedBy   = "Terraform"
    SecurityNote = "Rotate access keys every 90 days"
  })
}

# -----------------------------------------------------------------------------
# 2. PROGRAMMATIC ACCESS KEY  (store output in GitHub Secrets)
# -----------------------------------------------------------------------------
resource "aws_iam_access_key" "gitops_user_key" {
  user = aws_iam_user.gitops_user.name
}

# Store the secret in SSM Parameter Store (encrypted) for retrieval
resource "aws_ssm_parameter" "gitops_access_key_id" {
  name        = "/gitops/cicd/access-key-id"
  description = "GitOps IAM user access key ID"
  type        = "SecureString"
  value       = aws_iam_access_key.gitops_user_key.id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "gitops_secret_access_key" {
  name        = "/gitops/cicd/secret-access-key"
  description = "GitOps IAM user secret access key"
  type        = "SecureString"
  value       = aws_iam_access_key.gitops_user_key.secret

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# 3. IAM GROUP  (best practice: attach policies to group, not user directly)
# -----------------------------------------------------------------------------
resource "aws_iam_group" "gitops_group" {
  name = "gitops-cicd-group"
  path = "/gitops/"
}

resource "aws_iam_user_group_membership" "gitops_user_group" {
  user   = aws_iam_user.gitops_user.name
  groups = [aws_iam_group.gitops_group.name]
}

# =============================================================================
# 4. POLICY: ECR — Build, tag, push Docker images & auto-create repositories
# Scope: Only repositories prefixed with "retail-store-"
# =============================================================================
data "aws_iam_policy_document" "ecr_policy_doc" {
  # Allow GetAuthorizationToken at account level (required for docker login)
  statement {
    sid    = "ECRAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  # Repository-level operations scoped to retail-store-* repos only
  statement {
    sid    = "ECRRepositoryAccess"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetLifecyclePolicy",
      "ecr:ListTagsForResource"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/retail-store-*"
    ]
  }

  # Allow creating new retail-store-* ECR repositories (used in deploy.yml)
  statement {
    sid    = "ECRCreateRepository"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:SetRepositoryPolicy",
      "ecr:TagResource"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/retail-store-*"
    ]
  }
}

resource "aws_iam_policy" "ecr_policy" {
  name        = "GitOps-ECR-Policy"
  path        = "/gitops/"
  description = "Least-privilege ECR access for GitOps pipeline - retail-store repositories only"
  policy      = data.aws_iam_policy_document.ecr_policy_doc.json

  tags = local.common_tags
}

# =============================================================================
# 5. POLICY: EKS — Read cluster info & update kubeconfig for kubectl/ArgoCD
# Scope: Only the retail-store cluster
# =============================================================================
data "aws_iam_policy_document" "eks_policy_doc" {
  statement {
    sid    = "EKSDescribeCluster"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
      "eks:DescribeFargateProfile",
      "eks:ListFargateProfiles",
      "eks:DescribeAddon",
      "eks:ListAddons",
      "eks:AccessKubernetesApi"
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
    ]
  }

  # Allow listing clusters at account level (DescribeCluster needs specific ARN above)
  statement {
    sid    = "EKSListClustersGlobal"
    effect = "Allow"
    actions = [
      "eks:ListClusters"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_policy" {
  name        = "GitOps-EKS-Policy"
  path        = "/gitops/"
  description = "Read-only EKS access for GitOps pipeline to authenticate with the retail-store cluster"
  policy      = data.aws_iam_policy_document.eks_policy_doc.json

  tags = local.common_tags
}

# =============================================================================
# 6. POLICY: KMS — Decrypt ECR images (cluster uses AES256 but KMS needed
#    for any future encrypted secrets / Helm chart secrets via SOPS)
# =============================================================================
data "aws_iam_policy_document" "kms_policy_doc" {
  statement {
    sid    = "KMSECRDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo"
    ]
    resources = [
      module.retail_app_eks.kms_key_arn
    ]
  }
}

resource "aws_iam_policy" "kms_policy" {
  name        = "GitOps-KMS-Policy"
  path        = "/gitops/"
  description = "Scoped KMS access for EKS cluster encryption key"
  policy      = data.aws_iam_policy_document.kms_policy_doc.json

  tags = local.common_tags
}

# =============================================================================
# 7. POLICY: ELB & VPC Read — Needed for Helm chart deployments that provision
#    NLBs (ingress-nginx) and for ArgoCD health checks
# =============================================================================
data "aws_iam_policy_document" "elb_vpc_readonly_doc" {
  statement {
    sid    = "ELBReadOnly"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeLoadBalancerAttributes"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "VPCReadOnly"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeRouteTables",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "elb_vpc_readonly_policy" {
  name        = "GitOps-ELB-VPC-ReadOnly-Policy"
  path        = "/gitops/"
  description = "Read-only ELB and VPC access for GitOps pipeline health checks"
  policy      = data.aws_iam_policy_document.elb_vpc_readonly_doc.json

  tags = local.common_tags
}

# =============================================================================
# 8. POLICY: SSM — Read-only access to retrieve stored secrets for the pipeline
# =============================================================================
data "aws_iam_policy_document" "ssm_readonly_doc" {
  statement {
    sid    = "SSMReadGitOpsSecrets"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DescribeParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/gitops/*"
    ]
  }
}

resource "aws_iam_policy" "ssm_readonly_policy" {
  name        = "GitOps-SSM-ReadOnly-Policy"
  path        = "/gitops/"
  description = "Read-only access to GitOps-scoped SSM parameters"
  policy      = data.aws_iam_policy_document.ssm_readonly_doc.json

  tags = local.common_tags
}

# =============================================================================
# 9. DENY POLICY — Explicit deny for high-risk actions regardless of other
#    policies. This is a security guardrail (cannot be overridden by Allow).
# =============================================================================
data "aws_iam_policy_document" "gitops_deny_doc" {
  statement {
    sid    = "DenyDestructiveActions"
    effect = "Deny"
    actions = [
      # Prevent IAM privilege escalation
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:PutUserPolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:AttachRolePolicy",
      "iam:PassRole",
      # Prevent infrastructure destruction
      "eks:DeleteCluster",
      "eks:DeleteNodegroup",
      "ec2:TerminateInstances",
      "ec2:DeleteVpc",
      "ec2:DeleteSubnet",
      "ecr:DeleteRepository",
      "ecr:DeleteRepositoryPolicy",
      # Prevent billing/account changes
      "aws-portal:ModifyBilling",
      "organizations:*",
      # Prevent KMS key deletion
      "kms:DeleteImportedKeyMaterial",
      "kms:ScheduleKeyDeletion"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "gitops_deny_policy" {
  name        = "GitOps-Deny-Destructive-Policy"
  path        = "/gitops/"
  description = "Explicit DENY guardrail for destructive actions - always applied to GitOps user"
  policy      = data.aws_iam_policy_document.gitops_deny_doc.json

  tags = local.common_tags
}

# =============================================================================
# 10. ATTACH ALL POLICIES TO THE GROUP
# =============================================================================
resource "aws_iam_group_policy_attachment" "ecr" {
  group      = aws_iam_group.gitops_group.name
  policy_arn = aws_iam_policy.ecr_policy.arn
}

resource "aws_iam_group_policy_attachment" "eks" {
  group      = aws_iam_group.gitops_group.name
  policy_arn = aws_iam_policy.eks_policy.arn
}

resource "aws_iam_group_policy_attachment" "kms" {
  group      = aws_iam_group.gitops_group.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

resource "aws_iam_group_policy_attachment" "elb_vpc_readonly" {
  group      = aws_iam_group.gitops_group.name
  policy_arn = aws_iam_policy.elb_vpc_readonly_policy.arn
}

resource "aws_iam_group_policy_attachment" "ssm_readonly" {
  group      = aws_iam_group.gitops_group.name
  policy_arn = aws_iam_policy.ssm_readonly_policy.arn
}

# Deny policy is attached directly to the user (not the group) so it
# cannot be bypassed by changing group membership
resource "aws_iam_user_policy_attachment" "deny" {
  user       = aws_iam_user.gitops_user.name
  policy_arn = aws_iam_policy.gitops_deny_policy.arn
}

# NOTE: data "aws_caller_identity" "current" is already declared in locals.tf
