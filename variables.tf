variable "application_name" {
  description = "The name of the application that owns this database."
  type        = string
}

variable "database_name" {
  description = "The name of the database. If not set, it will be the same as the application"
  type        = string

  default = null
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

/*
 * == Database Setup
 */
variable "engine" {
  description = "The database engine to use."
  type        = string

  validation {
    condition     = var.engine == "postgresql" || var.engine == "mysql"
    error_message = "Only `mysql` or `postgresql` are valid engines."
  }
}

variable "engine_version" {
  description = "The version for the database engine. Defaults to latest. Destructive to modify."
  type        = string

  default = null
}

variable "master_username" {
  description = "The username of the master user"
  type        = string

  default = null
}

variable "master_password" {
  description = "The password of the master user"
  type        = string

  default = null
}

/*
 * == Instance Setup
 */
variable "number_of_instances" {
  description = "The number of instances to create for this cluster."
  type        = number

  default = 1
}

variable "instance_class" {
  description = "The instance class to use for this cluster"
  type        = string

  default = "db.t4g.medium"
}

variable "enable_performance_insights" {
  description = "Should performance insights be enabled?"
  type        = bool

  default = true
}

/*
 * == Backup and Maintinance
 */
variable "allow_major_version_upgrade" {
  description = "Should the database be allowed to upgrade to the next major version?"
  type        = bool

  default = false
}

variable "allow_minor_version_upgrade" {
  description = "Should the database be allowed to keep up to date with the latest minor version?"
  type        = bool

  default = true
}

variable "apply_immediately" {
  description = "Should changes be applied immediately or in the maintenance window?"
  type        = bool

  default = true
}

variable "backup_retention_period" {
  description = "The amount of days that backups should be kept"
  type        = number

  default = 3
}

variable "preferred_backup_window" {
  description = "The timeframe for backups can be done"
  type        = string

  default = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "The timeframe for when maintenance can be done"
  type        = string

  default = "sat:04:00-sat:05:00"
}

/*
 * == Networking
 */
variable "availability_zones" {
  description = "Availability zones to deploy to. Must be at least 3."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 3
    error_message = "There must be at least three availability zones."
  }
}

variable "vpc_id" {
  description = "VPC that the cluster will live in"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets to place database instances in."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups that can access the database"
  type        = list(string)

  default = []
}

/*
 * == Restoring from backup
 */
variable "restore_from_snapshot" {
  description = "Restore your database from an existing RDS snapshot using a snapshot-id or ARN"
  type        = string

  default = null
}

variable "replicate_from_database" {
  description = "Replicate from your existing database instance or cluster."
  type        = string

  default = null
}

variable "clone_from_existing_cluster_arn" {
  description = "If you want to clone your data from an existing cluster"
  type        = string

  default = null
}

variable "ca_cert_identifier" {
  description = "Identifier of the CA certificate for the DB instance"
  type        = string
  default     = "rds-ca-rsa2048-g1"
}
