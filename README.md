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

- **Managed (recommended):** Set `manage_master_user_password = true`. Aurora creates and stores the password in AWS Secrets Manager.
- **Self-managed:** Set `master_password` directly. You are responsible for storing and rotating the secret.

#### Automatic rotation

Rotation is enabled by default every 30 days when `manage_master_user_password = true`. Override the interval with `rotate_after_days`:

```hcl
credentials_auto_rotation = {
  rotate_after_days = 14
}
```

Set `enabled = false` to temporarily disable rotation without removing the configuration:

```hcl
credentials_auto_rotation = {
  enabled = false
}
```


#### Migrating an existing cluster to managed passwords

Enabling `manage_master_user_password` on an existing cluster will cause brief downtime. Set `rotate_immediately = false` to prevent Aurora from rotating the password a second time immediately after the rotation schedule is created.

```hcl
module "database" {
  ...
  manage_master_user_password = true
  credentials_auto_rotation = {
    rotate_immediately = false
  }
}
```

Migration requires **two applies** due to a limitation in the AWS provider: `master_user_secret` is not marked as known-after-apply when `manage_master_user_password` is toggled, so the rotation schedule cannot be planned until the cluster has been updated. Apply the cluster first, then apply everything:

```bash
terraform apply -target=module.database.aws_rds_cluster.this
terraform apply
```

Plan for a short maintenance window covering both applies. Once complete and your application is healthy, you can remove `rotate_immediately = false` (or leave it, it only affects the initial creation of the rotation schedule).

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
