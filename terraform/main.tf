# ==========================================
# 1. Réseau (VPC & Subnets) - Isolation réseau
# ==========================================
resource "huaweicloud_vpc" "main" {
  name = "vpc-devsecops-prod"
  cidr = var.vpc_cidr
}

resource "huaweicloud_vpc_subnet" "cce_nodes" {
  name       = "subnet-cce-nodes"
  cidr       = var.cce_subnet_cidr
  gateway_ip = cidrhost(var.cce_subnet_cidr, 1)
  vpc_id     = huaweicloud_vpc.main.id
}

resource "huaweicloud_vpc_subnet" "rds_data" {
  name       = "subnet-rds-data"
  cidr       = var.rds_subnet_cidr
  gateway_ip = cidrhost(var.rds_subnet_cidr, 1)
  vpc_id     = huaweicloud_vpc.main.id
}

# ==========================================
# 2. Security Groups (Moindre Privilège)
# ==========================================
# SG pour les noeuds Kubernetes
resource "huaweicloud_networking_secgroup" "cce_nodes_sg" {
  name        = "sg-cce-nodes"
  description = "Security group for CCE cluster nodes"
}

# SG pour la base de données RDS
resource "huaweicloud_networking_secgroup" "rds_sg" {
  name        = "sg-rds-postgres"
  description = "Security group for RDS PostgreSQL instance"
}

# Règle stricte: N'autoriser le trafic entrant sur la BD QUE depuis les noeuds K8s
resource "huaweicloud_networking_secgroup_rule" "rds_allow_cce" {
  security_group_id = huaweicloud_networking_secgroup.rds_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = huaweicloud_networking_secgroup.cce_nodes_sg.id
  description       = "Allow PostgreSQL traffic only from CCE nodes"
}

# ==========================================
# 3. Kubernetes Cluster (CCE)
# ==========================================
resource "huaweicloud_cce_cluster_v3" "k8s_cluster" {
  name                   = "cce-devsecops-prod"
  cluster_type           = "VirtualMachine"
  flavor_id              = "cce.s2.small" # Type de control plane
  vpc_id                 = huaweicloud_vpc.main.id
  subnet_id              = huaweicloud_vpc_subnet.cce_nodes.id
  container_network_type = "overlay_l2"
  authentication_mode    = "rbac" # Force RBAC (DevSecOps requirement)
}

resource "huaweicloud_cce_node_pool_v3" "node_pool" {
  cluster_id               = huaweicloud_cce_cluster_v3.k8s_cluster.id
  name                     = "pool-ml-workers"
  os                       = "EulerOS 2.9" # OS durci
  initial_node_count       = 2
  flavor_id                = "c6s.large.2" # 2 vCPU, 4GB RAM
  
  scall_enable             = true # Active l'auto-scaling
  min_node_count           = 2
  max_node_count           = 5

  root_volume {
    size       = 40
    volumetype = "SSD"
  }
  data_volumes {
    size       = 100
    volumetype = "SSD"
  }
}

# ==========================================
# 4. Base de Données Relationnelle (RDS - PostgreSQL)
# ==========================================
resource "huaweicloud_rds_instance" "db" {
  name                = "rds-ml-prod"
  flavor              = "rds.pg.n1.large.2"
  vpc_id              = huaweicloud_vpc.main.id
  subnet_id           = huaweicloud_vpc_subnet.rds_data.id
  security_group_id   = huaweicloud_networking_secgroup.rds_sg.id
  availability_zone   = [data.huaweicloud_availability_zones.myaz.names[0], data.huaweicloud_availability_zones.myaz.names[1]]
  
  db {
    type     = "PostgreSQL"
    version  = "13"
    password = var.db_password # Le mot de passe provient d'une variable sensible (ex: injecté par CI/Vault)
  }

  volume {
    type = "CLOUD_SSD"
    size = 100
  }

  backup_strategy {
    start_time = "02:00-03:00"
    keep_days  = 7
  }
}

data "huaweicloud_availability_zones" "myaz" {}
