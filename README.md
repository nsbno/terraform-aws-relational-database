# Relational Database Using Aurora

Set up a PostgreSQL or MySQL database using AWS Aurora with sane defaults.

Using this module, you don't have to worry about backups or managing hosts.

## About

See [variables.tf](variables.tf) and [outputs.tf](outputs.tf) for all available options.

```hcl
module "database" {
  source = "github.com/nsbno/terraform-aws-relational-database?ref=x.y.z"

  application_name = "tut-tut-tog"

  engine         = "postgresql"
  engine_version = "17"

  vpc_id             = "vpc-12345"
  subnet_ids         = ["subnet-1a2b3c", "subnet-4b5c6d", "subnet-7a8b9c"]
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  security_group_ids = ["sg-54321"]

  manage_master_user_password = true
}
```

A runnable example can be found in [examples/simple-postgres](examples/simple-postgres/main.tf).

## Connecting your application

After provisioning the database, you need to wire it up to your application.

### Network access

The module creates a security group for the cluster.
Pass your application's security group ID via `security_group_ids` so it can reach the database:

```hcl
module "database" {
  ...
  security_group_ids = [module.service.security_group_id]
}
```

### Managed password rotation

When `manage_master_user_password = true`, Aurora stores and rotates the password in Secrets Manager.
Your application never sees the password directly — it fetches the current credentials from the secret at runtime.

> **Migrating an existing cluster:** Enabling this on an already-running cluster requires two applies.
> In the first apply, only set `manage_master_user_password = true` and leave your application config pointing at its existing secret — Aurora will rotate the password but your app keeps running.
> In the second apply, update your application to reference `master_user_secret_arn` and remove the old manually-managed secret.
> Keep the two applies close together to minimise downtime between the password change and your app picking up the new credentials.

1. Grant your task role permission to read the secret:

    ```hcl
    module "permissions" {
      ...
      secrets_manager = [
        {
          arns        = [module.database.master_user_secret_arn]
          permissions = ["get"]
        }
      ]
    }
    ```

2. Pass the endpoint and secret ARN to your application, for example via SSM parameters:

    ```hcl
    resource "aws_ssm_parameter" "db_endpoint" {
      name           = "/my-app/config/db.endpoint"
      type           = "String"
      insecure_value = module.database.endpoint
    }

    resource "aws_ssm_parameter" "db_secret_arn" {
      name           = "/my-app/config/db.secretArn"
      type           = "String"
      insecure_value = module.database.master_user_secret_arn
    }
    ```

### Data API

When `enable_data_api = true`, your application can query the database over HTTPS without a persistent connection.
This requires Aurora PostgreSQL >= 17.7.

> **Note:** The Data API is not supported on burstable instance classes (`db.t` family). You must use a memory-optimized instance such as `db.r6g.large` or larger. Setting `enable_data_api = true` with the default `db.t4g.medium` will cause an error on apply.

In addition to the Secrets Manager permission above, grant the task role access to the RDS Data API:

```hcl
resource "aws_iam_role_policy" "data_api" {
  role = module.service.task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "rds-data:ExecuteStatement",
        "rds-data:BatchExecuteStatement",
        "rds-data:BeginTransaction",
        "rds-data:CommitTransaction",
        "rds-data:RollbackTransaction",
      ]
      Resource = module.database.cluster_arn
    }]
  })
}
```

## Considerations when creating a database cluster

You still have to make some decisions about your database, even though it's managed.
Here are some things to look out for.

### Choosing Instance Types

The instance type you should choose is based on your workload.
By default, a `db.t4g.medium` is used, which should be enough for your initial deployment (and maybe forever for smaller apps).

You must select the instance type that:

- allows for the amount of connections you actually need
- has enough temporary storage to hold your queries and index builds in memory

You can find out more in the [Aurora management docs](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.Managing.html).

When your application is in production, monitor the impact of your instance type by checking the `VolumeReadIOPS` and `BufferCacheHitRatio` metrics.
Read IOPS should stay low and the buffer cache hit ratio should stay high — values that don't match this indicate you should upgrade to a larger instance type.

### Picking versions for the database

The engine version can be either just a major version, or a major and minor version.

For most deployments, it is recommended to specify only the major version, since AWS will automatically upgrade minor versions by default.

Disable automatic minor version upgrades if you need a specific minor version by setting `allow_minor_version_upgrade = false`.
