# =============================================================================
# DNS and TLS — Route 53 hosted zone, domain NS, ACM wildcard certificate
# =============================================================================
# Exported via outputs.tf: domain_name, acm_certificate_arn (used by gitops/ingress).

resource "aws_route53_zone" "main" {
  name          = var.domain_name
  force_destroy = true

  tags = {
    Name = var.domain_name
  }
}

# Adopt an already-registered domain (Route 53 Domains) into Terraform state — does not re-register it.
import {
  to = aws_route53domains_registered_domain.main
  id = var.domain_name
}

# Point the domain registration at this hosted zone's nameservers so public DNS uses our Route 53 zone.
resource "aws_route53domains_registered_domain" "main" {
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = aws_route53_zone.main.name_servers
    content {
      name = name_server.value
    }
  }

  # Only manage nameservers — leave contacts, renewal, and transfer lock unchanged in AWS.
  lifecycle {
    ignore_changes = [
      admin_contact,
      billing_contact,
      registrant_contact,
      tech_contact,
      auto_renew,
      transfer_lock,
    ]
  }
}

# TLS certificate for root domain and *.domain (used by ALB Ingress in gitops/).
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.domain_name
  }
}

# Root + wildcard share one CNAME validation record — a single record is enough.
resource "aws_route53_record" "cert_validation" {
  zone_id = aws_route53_zone.main.zone_id
  name    = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_value]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]

  depends_on = [aws_route53domains_registered_domain.main]
}
