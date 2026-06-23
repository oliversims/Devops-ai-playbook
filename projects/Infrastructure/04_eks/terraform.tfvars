region = "us-east-1"

tfstate_bucket = "tfstate-dev-us-east-1-602rfk" # Must match provider.tf backend bucket

cluster_name    = "eks-cluster" # Must match 02_vpc
node_group_name = "eks-node-group"

instance_types = ["m7i-flex.large"]
capacity_type  = "ON_DEMAND"

desired_size = 2
min_size     = 1
max_size     = 3

disk_size = 30
