output "cluster_arn" {
  description = "The cluster's ARN"
  value       = aws_rds_cluster.this.arn
}

output "cluster_id" {
  description = "The cluster's identifier"
  value       = aws_rds_cluster.this.id
}

output "port" {
  description = "The port that users can connect to the cluster on"
  value       = aws_rds_cluster.this.port
}

output "endpoint" {
  description = "Endpoint to connect to the clusters writer"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Endpoint to connect to the clusters reader(s)"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "database_name" {
  description = "The name of the created database"
  value       = aws_rds_cluster.this.database_name
}

output "master_username" {
  description = "Username for the master user on the cluster"
  value       = aws_rds_cluster.this.master_username
}

output "master_password" {
  description = "Password for the master user on the cluster"
  sensitive   = true
  value       = aws_rds_cluster.this.master_password
}

output "final_snapshot_identifier" {
  description = "Identifier for the final snapshot created on destroy"
  value       = aws_rds_cluster.this.final_snapshot_identifier
}

output "security_group_id" {
  description = "The cluster's security group. Create rules for this to get access to the instance."
  value       = aws_security_group.this.id
}
