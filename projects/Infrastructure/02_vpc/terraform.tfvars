region = "us-east-1"

vpc_name = "EKS-Demo-VPC"
vpc_cidr = "10.1.0.0/16"

subnets = [
  {
    name              = "subnet-1"
    cidr_block        = "10.1.1.0/24"
    availability_zone = "us-east-1a"
  },
  {
    name              = "subnet-2"
    cidr_block        = "10.1.2.0/24"
    availability_zone = "us-east-1b"
  },
  {
    name              = "subnet-3"
    cidr_block        = "10.1.3.0/24"
    availability_zone = "us-east-1c"
  }
]

cluster_name = "eks-cluster" # Must match 04_eks

# Replace with your real domain before running terraform apply.
domain_name = "simsoliver.com"
