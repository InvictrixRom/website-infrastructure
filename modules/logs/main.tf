resource "aws_cloudwatch_log_group" "wordpress_logs" {
  name = "wordpress"
  retention_in_days = 30
}
