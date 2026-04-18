output "cluster_id" {
  description = "The ID of the CCE Cluster"
  value       = huaweicloud_cce_cluster_v3.k8s_cluster.id
}

output "rds_endpoint" {
  description = "The private connection IP of the RDS Database. Securely accessible only inside the VPC."
  value       = huaweicloud_rds_instance.db.private_ips[0]
}

# Jamais d'output des mots de passe en clair !
