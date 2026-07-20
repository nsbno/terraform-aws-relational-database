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

When enabling rotation on an existing database for the first time, set `rotate_immediately = false` to avoid an immediate password change before your application is ready to read the new secret.

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
