resource "aws_cloudwatch_log_group" "wordpress_logs" {
  name              = "wordpress"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "mysql_logs" {
  name              = "mysql"
  retention_in_days = 30
}
