resource "aws_lb" "load_balancer" {
  name               = "${var.aws_name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.security_group}"]
  subnets            = ["${var.public_subnet}", "${var.public_second_subnet}"]
  enable_deletion_protection = true

  tags {
    Name = "${var.name}"
  }
}

resource "aws_lb_listener" "bastion" {
  load_balancer_arn = "${aws_lb.load_balancer.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  certificate_arn   = "${var.certificate_arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.front_end.arn}"
  }
}

resource "aws_lb_listener" "https_to_http" {
  load_balancer_arn = "${aws_lb.load_balancer.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "front_end" {
  name     = "${var.aws_name}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc}"
}
