

# glue_connection.tf

resource "aws_glue_connection" "redshift_jdbc_connection" {
  name            = "${var.project_name}-redshift-database-connection"
  connection_type = "JDBC"

  connection_properties = {
    # --- THIS LINE IS UPDATED ---
    "JDBC_CONNECTION_URL" = "jdbc:redshift://${aws_redshiftserverless_workgroup.main.endpoint[0].address}:${aws_redshiftserverless_workgroup.main.endpoint[0].port}/${aws_redshiftserverless_namespace.main.db_name}"
    # ----------------------------
    "SECRET_ID"        = aws_secretsmanager_secret.redshift_credentials.name
    "JDBC_ENFORCE_SSL" = "true"
  }

  physical_connection_requirements {
    subnet_id              = aws_subnet.private_a.id
    security_group_id_list = [aws_security_group.main.id]
    availability_zone      = data.aws_availability_zones.available.names[0]
  }

  tags = {
    Name = "${var.project_name}-GlueJDBCConnection"
  }
}

# This file defines the AWS Glue Connection to your Redshift Serverless database.
resource "aws_glue_connection" "redshift_connection" {
  name            = "${var.project_name}-redshift-connection"
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${aws_redshiftserverless_workgroup.main.endpoint[0].address}/${aws_redshiftserverless_namespace.main.db_name}"
    USERNAME            = aws_redshiftserverless_namespace.main.admin_username
    PASSWORD            = random_password.db_password.result
  }

  physical_connection_requirements {
    subnet_id              = aws_subnet.private_a.id
    security_group_id_list = [aws_security_group.main.id]
    availability_zone      = data.aws_availability_zones.available.names[0]
  }

  tags = {
    Name = "${var.project_name}-RedshiftConnection"
  }
}