provider "aws" {
  region     = "${var.region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

module "cluster" {
  source   = "modules/cluster"
  name     = "wordpress"
  aws_name = "wordpress"
}

module "logs" {
  source = "modules/logs"
}

resource "aws_iam_role" "my_ecs_instance_role" {
  name = "my_ecs_instance_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ecs" {
  name = "my_ecs_instance_profile"
  path = "/"
  role = "${aws_iam_role.my_ecs_instance_role.name}"
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_role" {
  role       = "${aws_iam_role.my_ecs_instance_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_instance" "instance" {
  ami                    = "${module.cluster.ecs_ami}"
  availability_zone      = "${var.region}a"
  instance_type          = "t2.micro"
  iam_instance_profile   = "${aws_iam_instance_profile.ecs.name}"
  vpc_security_group_ids = ["${aws_security_group.security_group.id}"]
  subnet_id              = "${module.cluster.public_subnet_id}"

  user_data = <<EOF
#!/bin/bash -xe
echo ECS_CLUSTER=${module.cluster.cluster_name} >> /etc/ecs/ecs.config
EOF

  tags {
    Name = "Invictrix Instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "security_group" {
  name        = "wordpress-securityGroup"
  description = "Wordpress Security Group"
  vpc_id      = "${module.cluster.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "Wordpress-SecurityGroup"
  }
}

module "wordpress_container_definition" {
  source          = "./modules/container_definitions/wordpress"
  container_image = "wordpress"
  db_host         = "mysql.wordpress.local"
  db_name         = "wordpress"
  db_user         = "wordpress"
  db_password     = "${data.terraform_remote_state.state.mysql_password}"
  aws_region      = "${var.region}"
  log_group       = "${module.logs.wordpress_logs_name}"
}

module "mysql_container_definition" {
  source          = "./modules/container_definitions/mysql"
  container_image = "mysql:5.7"
  mysql_database  = "wordpress"
  mysql_user      = "wordpress"
  mysql_password  = "${data.terraform_remote_state.state.mysql_password}"
  aws_region      = "${var.region}"
  log_group       = "${module.logs.mysql_logs_name}"
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "wordpress-ecs"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "wordpress_task_definition" {
  family                = "wordpress"
  container_definitions = "${module.wordpress_container_definition.json}"

  task_role_arn      = "${aws_iam_role.app_role.arn}"
  execution_role_arn = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_ecs_task_definition" "mysql_task_definition" {
  family                = "mysql"
  container_definitions = "${module.mysql_container_definition.json}"
  network_mode          = "awsvpc"

  task_role_arn      = "${aws_iam_role.app_role.arn}"
  execution_role_arn = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_ecs_service" "wordpress" {
  name            = "wordpress"
  cluster         = "${module.cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.wordpress_task_definition.arn}"
  desired_count   = 1
}

resource "aws_ecs_service" "mysql" {
  name            = "mysql"
  cluster         = "${module.cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.mysql_task_definition.arn}"
  desired_count   = 1

  service_registries {
    registry_arn   = "${aws_service_discovery_service.wordpress_service_discovery_service.arn}"
    container_name = "mysql"
  }

  network_configuration {
    security_groups = ["${aws_security_group.security_group.id}"]
    subnets         = ["${module.cluster.public_subnet_id}"]
  }
}

resource "aws_iam_role" "app_role" {
  name               = "wordpress-app-role"
  assume_role_policy = "${data.aws_iam_policy_document.app_role_assume_role_policy.json}"
}

resource "aws_iam_role_policy" "app_policy" {
  name   = "wordpress-app-policy"
  role   = "${aws_iam_role.app_role.id}"
  policy = "${data.aws_iam_policy_document.app_policy.json}"
}

data "aws_iam_policy_document" "app_policy" {
  statement {
    actions = [
      "ecs:DescribeClusters",
    ]

    resources = [
      "${module.cluster.cluster_arn}",
    ]
  }
}

data "aws_iam_policy_document" "app_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_instance.instance.id}"
  allocation_id = "${module.cluster.eip_id}"
}

resource "aws_service_discovery_private_dns_namespace" "wordpress_dns" {
  name        = "wordpress.local"
  description = "wordpress dns"
  vpc         = "${module.cluster.vpc_id}"
}

resource "aws_service_discovery_service" "wordpress_service_discovery_service" {
  name = "mysql"

  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.wordpress_dns.id}"

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
