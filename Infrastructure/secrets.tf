# secrets.tf

resource "aws_secretsmanager_secret" "redshift_credentials" {
  name = "${var.project_name}-redshift-creds"
  tags = {
    Name = "${var.project_name}-RedshiftSecret"
  }
}

resource "aws_secretsmanager_secret_version" "redshift_credentials_version" {
  secret_id = aws_secretsmanager_secret.redshift_credentials.id
  secret_string = jsonencode({
    username = aws_redshiftserverless_namespace.main.admin_username
    password = random_password.db_password.result
  })
}