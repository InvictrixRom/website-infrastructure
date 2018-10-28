module "task_definition_creator" {
  source                       = "../../cloudposse-aws-ecs-container-definition"
  container_name               = "mysql"
  container_image              = "${var.container_image}"
  container_memory             = 450
  container_memory_reservation = 128

  environment = [
    {
      name  = "MYSQL_USER"
      value = "${var.mysql_user}"
    },
    {
      name  = "MYSQL_PASSWORD"
      value = "${var.mysql_password}"
    },
    {
      name  = "MYSQL_DATABASE"
      value = "${var.mysql_database}"
    },
    {
      name  = "MYSQL_RANDOM_ROOT_PASSWORD"
      value = "yes"
    },
  ]

  log_driver = "awslogs"

  log_options = {
    awslogs-region        = "${var.aws_region}"
    awslogs-group         = "${var.log_group}"
    awslogs-stream-prefix = "mysql"
  }

  port_mappings = [
    {
      containerPort = 3306
      hostPort      = 3306
      protocol      = "tcp"
    },
  ]
}
