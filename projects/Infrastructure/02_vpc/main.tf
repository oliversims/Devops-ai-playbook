# VPC networking resources: VPC, public subnets, internet gateway, and routes.
# This stack must be applied before the EKS stack.

# Derived values from var.subnets — used by aws_subnet count and attributes.
locals {
  subnet_cidrs       = [for s in var.subnets : s.cidr_block]
  availability_zones = [for s in var.subnets : s.availability_zone]
}

# Isolated virtual network where EKS and other AWS resources run.
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Allows resources in public subnets to reach the internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Public subnets across multiple AZs — EKS nodes and load balancers are placed here.
resource "aws_subnet" "subnets" {
  count = length(local.subnet_cidrs)

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${count.index + 1}"

    # Tells AWS this subnet can host external load balancers for the cluster.
    "kubernetes.io/role/elb" = "1"
    # Links the subnet to the EKS cluster name (must match 04_eks).
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Routes all outbound traffic from public subnets to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Attaches each public subnet to the shared public route table.
resource "aws_route_table_association" "public" {
  count = length(local.subnet_cidrs)

  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route 53 hosted zone for your domain.
resource "aws_route53_zone" "main" {
  name          = var.domain_name
  force_destroy = true

  tags = {
    Name = var.domain_name
  }
}

# If your domain is registered in Route 53 Domains, point its nameservers at the zone above.
# Destroying this stack removes it from Terraform only — your domain registration stays.
import {
  to = aws_route53domains_registered_domain.main
  id = var.domain_name
}

resource "aws_route53domains_registered_domain" "main" {
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = aws_route53_zone.main.name_servers
    content {
      name = name_server.value
    }
  }

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

# TLS certificate for yourdomain.com and *.yourdomain.com.
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

# DNS record ACM needs to prove you own the domain.
# Root + wildcard share one CNAME — a single record is enough.
resource "aws_route53_record" "cert_validation" {
  zone_id = aws_route53_zone.main.zone_id
  name    = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_value]
  ttl     = 60

  allow_overwrite = true
}

# Waits until ACM marks the certificate as Issued.
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]

  depends_on = [aws_route53domains_registered_domain.main]
}