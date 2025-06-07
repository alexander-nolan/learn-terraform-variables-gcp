# Network outputs
output "network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "network_self_link" {
  description = "The URI of the VPC network"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "The created subnet resources"
  value       = module.vpc.subnets
}

# Load balancer outputs
output "load_balancer_ip" {
  description = "The external IP address of the load balancer"
  value       = module.lb.external_ip
}

# Instance outputs
output "instance_group" {
  description = "The instance group URL"
  value       = module.mig.instance_group
}

output "instance_template" {
  description = "The self-link of the instance template"
  value       = module.instance_template.self_link
}
