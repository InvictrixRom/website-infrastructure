provider "aws" {
  region = "${var.region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

module "cluster" {
  source   = "modules/cluster"
  name     = "wordpress"
  aws_name = "wordpress"
}

module "alb" {
  source               = "modules/alb"
  name                 = "wordpress"
  aws_name             = "wordpress"
  certificate_arn      = "${var.certificate_arn}"
  public_second_subnet = "${module.cluster.public_second_subnet_id}"
  public_subnet        = "${module.cluster.public_subnet_id}"
  vpc                  = "${module.cluster.vpc_id}"
  security_group       = "${aws_security_group.security_group.id}"
  front_end_container  = "${aws_ecs_task_definition.wordpress_task_definition.id}"
}

module "logs" {
  source = "modules/logs"
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "wordpress"
  subnet_ids = ["${module.cluster.public_second_subnet_id}","${module.cluster.public_subnet_id}"]

  tags {
    Name = "Wordpress DB Subnet Group"
  }
}

resource "aws_db_instance" "database" {
  allocated_storage      = 10
  identifier             = "wordpress"
  db_subnet_group_name   = "${aws_db_subnet_group.db_subnet_group.id}"
  multi_az               = "false"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  name                   = "wordpress"
  username               = "wordpress"
  password               = "jkMCjKMgKe7X4236jYqFfyarJKkzWCgi3v2ofWKrU"
  parameter_group_name   = "default.mysql5.7"
  vpc_security_group_ids = ["${aws_security_group.security_group.id}"]
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"

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
  role = "${aws_iam_role.ecs_instance_role.name}"
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_role" {
  role       = "${aws_iam_role.ecs_instance_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


resource "aws_launch_configuration" "wordpress_launch_configuration" {
  name          = "wordpress"
  image_id      = "${module.cluster.ecs_ami}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.security_group.id}"]

  user_data = <<EOF
#!/bin/bash -xe
echo ECS_CLUSTER=${module.cluster.cluster_name} >> /etc/ecs/ecs.config
EOF

  iam_instance_profile = "${aws_iam_instance_profile.ecs.arn}"
  ebs_optimized        = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "wordpress_autoscaling_group" {
  name                 = "wordpress"
  launch_configuration = "${aws_launch_configuration.wordpress_launch_configuration.name}"
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier  = ["${module.cluster.public_subnet_id}"]

  tags {
    key                 = "Name"
    value               = "wordpress"
    propagate_at_launch = true
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
  db_host     = "${aws_db_instance.database.endpoint}"
  db_name     = "wordpress"
  db_user     = "wordpress"
  db_password = "jkMCjKMgKe7X4236jYqFfyarJKkzWCgi3v2ofWKrU"
  aws_region  = "${var.region}"
  log_group   = "${module.logs.wordpress_logs_name}"
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

resource "aws_ecs_service" "wordpress" {
  name            = "wordpress"
  cluster         = "${module.cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.wordpress_task_definition.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${module.alb.lb_target_group}"
    container_name   = "wordpress"
    container_port   = 80
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