# terraform.tfvars

project_name     = "multi-region-app"
primary_region   = "us-west-2"
secondary_region = "us-east-1"

asg_min_size         = 2
asg_max_size         = 10
asg_desired_capacity = 4

# Add more variables as needed for your specific configuration