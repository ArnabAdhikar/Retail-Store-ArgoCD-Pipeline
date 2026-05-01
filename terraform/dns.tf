# =============================================================================
# ROUTE 53 DNS CONFIGURATION
# =============================================================================

# 1. Fetch the existing Hosted Zone
data "aws_route53_zone" "main" {
  name         = "arnaba075.com"
  private_zone = false
}

# 2. Wait for Load Balancer to be provisioned
# This gives AWS time to assign a DNS name to the NLB
resource "time_sleep" "wait_for_lb" {
  create_duration = "60s"
  depends_on      = [module.eks_addons]
}

# 3. Get the NGINX Ingress Load Balancer service details
data "kubernetes_service_v1" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [time_sleep.wait_for_lb]
}

# 4. Create the Route53 Record
resource "aws_route53_record" "retail_store" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "retail_store.arnaba075.com"
  type    = "CNAME"
  ttl     = 300
  
  # Use try() to handle cases where the hostname isn't available yet during the first run
  records = [
    try(data.kubernetes_service_v1.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname, "pending.arnaba075.com")
  ]

  # Allow the value to update once the LB is actually ready without failing the initial apply
  lifecycle {
    ignore_changes = []
  }
}

# Output the URL
output "application_url" {
  description = "The URL to access the application"
  value       = "https://retail_store.arnaba075.com"
}
