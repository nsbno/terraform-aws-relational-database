# Relational Database Using Aurora

Provision an Aurora PostgreSQL or MySQL cluster with automated backups, storage encryption, and password management configured by default.

## Usage

A runnable example can be found in [examples/simple-postgres](examples/simple-postgres/main.tf).

```hcl
module "database" {
  source = "github.com/nsbno/terraform-aws-relational-database?ref=x.y.z"

  application_name = "tut-tut-tog"

  engine         = "postgresql"
  engine_version = "17"

  vpc_id             = data.aws_vpc.this.id
  subnet_ids         = data.aws_subnets.private_subnets.ids
  availability_zones = data.aws_availability_zones.current.names
  security_group_ids = [module.service.security_group_id]

  manage_master_user_password = true
}
```

See [variables.tf](variables.tf) and [outputs.tf](outputs.tf) for all available options.

## Key decisions

### Password management

You have two options for the master password:

- **Managed (recommended):** Set `manage_master_user_password = true`. Aurora creates and stores the password in AWS Secrets Manager. Rotation is enabled by default every 30 days.
- **Self-managed:** Set `master_password` directly. You are responsible for storing and rotating the secret.

#### Migrating an existing cluster to managed passwords

Enabling `manage_master_user_password` on an existing cluster requires **two Terraform applies** and will cause brief downtime. Always set `rotate_immediately = false` when migrating such that Aurora does not rotate the password a second time on the second apply.

There are two moments where the password changes during migration:

**Apply 1**: Aurora immediately generates a new password and stores it in Secrets Manager. The old password stops working at this point. Because Terraform plans everything upfront against the current state (where the secret doesn't exist yet), `master_user_secret_arn` outputs `null` and the rotation schedule is not created yet.

**Apply 2**: The ARN is now in state, so the rotation schedule is created. Without `rotate_immediately = false`, Aurora would rotate the password *again* immediately at this point, causing a second outage.

To minimise downtime, keep a fallback secret with the old credentials and use `coalesce()` so your application switches to the managed secret automatically on the second apply rather than staying down between the two:

```hcl
locals {
  db_credentials_arn = coalesce(module.database.master_user_secret_arn, aws_secretsmanager_secret.db_credentials_fallback.arn)
}
```

Plan for a short maintenance window covering both applies. Once the second apply is complete and your application is healthy, remove the fallback secret.

### Instance type

The default instance type is `db.t4g.medium`, which is sufficient for most initial deployments. Choose an instance type that:

- Supports the number of concurrent connections your app needs
- Has enough memory to hold queries and index builds

Once in production, monitor `VolumeReadIOPS` and `BufferCacheHitRatio`. Low read IOPS and a high cache hit ratio mean your instance is well-sized.

See the [Aurora management docs](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.Managing.html) for more details.

### Engine version

Specify only the major version (e.g. `"17"`) to allow AWS to manage minor version upgrades automatically. Pin to a specific minor version and set `allow_minor_version_upgrade = false` only when you have a specific reason to do so.

### Deletion protection

Deletion protection is enabled by default (`deletion_protection = true`). You must explicitly disable it before you can destroy the cluster. This is intentional to prevent accidental data loss.

## Connecting your application

The module creates a security group for the cluster. Pass your application's security group ID via `security_group_ids` so it can reach the database:

```hcl
module "database" {
  ...
  security_group_ids = [module.service.security_group_id]
}
```
