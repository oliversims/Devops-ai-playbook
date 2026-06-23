# =============================================================================
# VPC networking — virtual network, public subnets, internet access
# =============================================================================
# Exported via outputs.tf for 04_eks (subnet_ids) and 05_argocd (vpc_id).

locals {
  subnet_cidrs       = [for s in var.subnets : s.cidr_block]
  availability_zones = [for s in var.subnets : s.availability_zone]
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Public subnets across multiple AZs — EKS nodes and ALBs are placed here.
resource "aws_subnet" "subnets" {
  count = length(local.subnet_cidrs)

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${count.index + 1}"

    # Required for external Application Load Balancers.
    "kubernetes.io/role/elb" = "1"
    # Links subnet to the EKS cluster (cluster_name must match 04_eks).
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count = length(local.subnet_cidrs)

  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = aws_route_table.public.id
}
