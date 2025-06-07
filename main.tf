terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 7.0"

  project_id   = var.project_id
  network_name = "${var.project_name}-${var.environment}"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name   = "private-subnet-0"
      subnet_ip     = var.private_subnet_cidr_blocks[0]
      subnet_region = var.region
    },
    {
      subnet_name   = "private-subnet-1"
      subnet_ip     = var.private_subnet_cidr_blocks[1]
      subnet_region = var.region
    },
    {
      subnet_name   = "public-subnet-0"
      subnet_ip     = var.public_subnet_cidr_blocks[0]
      subnet_region = var.region
    },
    {
      subnet_name   = "public-subnet-1"
      subnet_ip     = var.public_subnet_cidr_blocks[1]
      subnet_region = var.region
    }
  ]

  routes = [
    {
      name              = "egress-internet"
      description       = "Route through IGW to access internet"
      destination_range = "0.0.0.0/0"
      next_hop_internet = "true"
    }
  ]
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 5.0"

  name    = "nat-router"
  project = var.project_id
  region  = var.region
  network = module.vpc.network_name

  nats = [{
    name                               = "nat-config"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    subnetworks = [
      {
        name                     = module.vpc.subnets["${var.region}/private-subnet-0"].self_link
        source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
        secondary_ip_range_names = []
      },
      {
        name                     = module.vpc.subnets["${var.region}/private-subnet-1"].self_link
        source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
        secondary_ip_range_names = []
      }
    ]
  }]
}

module "lb" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "~> 9.0"

  project           = var.project_id
  name              = "lb-${random_string.lb_id.result}"
  target_tags       = ["allow-health-check"]
  firewall_networks = [module.vpc.network_name]

  backends = {
    default = {
      description                     = null
      protocol                       = "HTTP"
      port                           = 80
      port_name                      = "http"
      timeout_sec                    = 10
      connection_draining_timeout_sec = null
      enable_cdn                     = false
      security_policy                = null
      custom_request_headers         = null
      custom_response_headers        = null
      compression_mode               = null

      health_check = {
        check_interval_sec  = 10
        timeout_sec         = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
        request_path        = "/index.html"
        port               = 80
        host               = null
        logging            = null
      }

      log_config = {
        enable = false
        sample_rate = null
      }

      groups = [
        {
          group = module.mig.instance_group
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = null
        oauth2_client_secret = null
      }
    }
  }
}

module "mig" {
  source  = "terraform-google-modules/vm/google//modules/mig"
  version = "~> 8.0"

  project_id        = var.project_id
  region           = var.region
  target_size      = var.instance_count
  hostname         = "web"
  instance_template = module.instance_template.self_link

  named_ports = [{
    name = "http"
    port = 80
  }]
}

module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 8.0"

  project_id        = var.project_id
  region           = var.region
  subnetwork       = module.vpc.subnets["${var.region}/private-subnet-0"].self_link
  service_account  = null

  name_prefix    = "${var.project_name}-${var.environment}"
  machine_type   = "e2-micro"
  tags           = ["web-server", "allow-health-check"]

  source_image         = "debian-11"
  source_image_family  = "debian-11"
  source_image_project = "debian-cloud"

  startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    systemctl start apache2
    systemctl enable apache2
  EOF
}

# Random string for unique names
resource "random_string" "lb_id" {
  length  = 3
  special = false
  lower   = true
  upper   = false
  numeric = true
}
