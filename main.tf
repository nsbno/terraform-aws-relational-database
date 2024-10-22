terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    }
  }
}

/*
 * == Networking
 */
resource "aws_db_subnet_group" "this" {
  name_prefix = var.application_name
  description = "Used for ${var.application_name} Aurora cluster"

  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.application_name}-aurora-cluster"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.application_name}-aurora-cluster"
  description = "Used for ${var.application_name} Aurora cluster"

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.application_name}-aurora-cluster"
  })
}

resource "aws_security_group_rule" "from_external" {
  count = length(var.security_group_ids)

  security_group_id = var.security_group_ids[count.index]
  type              = "egress"

  source_security_group_id = aws_security_group.this.id

  protocol  = "TCP"
  from_port = aws_rds_cluster.this.port
  to_port   = aws_rds_cluster.this.port
}

resource "aws_security_group_rule" "to_database" {
  count = length(var.security_group_ids)

  security_group_id = aws_security_group.this.id
  type              = "ingress"

  source_security_group_id = var.security_group_ids[count.index]

  protocol  = "TCP"
  from_port = aws_rds_cluster.this.port
  to_port   = aws_rds_cluster.this.port
}

/*
 * == Cluster
 *
 * Setup the actual aurora cluster and it's instances!
 */
resource "random_pet" "master_username" {
  count = var.master_username != null ? 0 : 1

  length    = 2
  separator = "" # Avoid special characters for the separator by using no separator
}

resource "random_password" "master_password" {
  count = var.master_password != null ? 0 : 1

  length  = 24
  special = false
}

resource "random_id" "snapshot_identifier" {
  byte_length = 4

  keepers = {
    id = var.application_name
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = var.application_name

  # Networking
  availability_zones     = var.availability_zones
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  # Database Setup
  engine         = "aurora-${var.engine}"
  engine_version = var.engine_version
  # The application name might contain non-alphanumeric, which is not allowed for database names.
  database_name     = var.replicate_from_database != null ? null : (var.database_name != null ? var.database_name : replace(var.application_name, "/[^a-zA-Z\\d]/", ""))
  storage_encrypted = true
  master_username   = var.replicate_from_database != null ? null : (var.master_username != null ? var.master_username : random_pet.master_username[0].id)
  master_password   = var.replicate_from_database != null ? null : (var.master_password != null ? var.master_password : random_password.master_password[0].result)

  # Deletion Protection
  deletion_protection = var.deletion_protection

  # Backup & Maintenance
  apply_immediately            = var.apply_immediately
  final_snapshot_identifier    = "${var.application_name}-${random_id.snapshot_identifier.hex}"
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  allow_major_version_upgrade  = var.allow_major_version_upgrade

  # Replicate with zero downtime
  replication_source_identifier = var.replicate_from_database
  # For restoring from snapshot
  snapshot_identifier = var.restore_from_snapshot

  tags = var.tags

  dynamic "restore_to_point_in_time" {
    for_each = var.clone_from_existing_cluster_arn != null ? [var.clone_from_existing_cluster_arn] : []

    content {
      source_cluster_identifier  = var.clone_from_existing_cluster_arn
      restore_type               = "copy-on-write"
      use_latest_restorable_time = true
    }
  }

  lifecycle {
    ignore_changes = [
      snapshot_identifier,
      restore_to_point_in_time,
    ]
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.number_of_instances

  cluster_identifier = aws_rds_cluster.this.id

  instance_class = var.instance_class

  identifier_prefix          = "${aws_rds_cluster.this.cluster_identifier}-${count.index}"
  engine                     = aws_rds_cluster.this.engine
  engine_version             = aws_rds_cluster.this.engine_version
  auto_minor_version_upgrade = var.allow_minor_version_upgrade

  performance_insights_enabled = var.enable_performance_insights
  apply_immediately            = var.apply_immediately
  ca_cert_identifier           = var.ca_cert_identifier

  tags = var.tags

  lifecycle {
    # If, for example, the instance class is changed, then make sure that we
    # have a new instance up and running before the old one is killed.
    create_before_destroy = true
  }
}
