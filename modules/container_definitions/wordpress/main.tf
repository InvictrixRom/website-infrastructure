module "task_definition_creator" {
  source                       = "../../cloudposse-aws-ecs-container-definition"
  container_name               = "wordpress"
  container_image              = "${var.container_image}"
  container_memory             = 768
  container_memory_reservation = 512

  environment = [
    {
      name  = "WORDPRESS_DB_HOST"
      value = "${var.db_host}"
    },
    {
      name  = "WORDPRESS_DB_USER"
      value = "${var.db_user}"
    },
    {
      name  = "WORDPRESS_DB_PASSWORD"
      value = "${var.db_password}"
    },
    {
      name  = "WORDPRESS_DB_NAME"
      value = "${var.db_name}"
    }
  ]

  log_driver = "awslogs"
  log_options = {
      awslogs-region = "${var.aws_region}"
      awslogs-group = "${var.log_group}"
      awslogs-stream-prefix = "wordpress"
  }

  port_mappings = [
    {
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }
  ]
}
