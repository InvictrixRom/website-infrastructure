output "alb" {
  value = "${aws_lb.load_balancer.arn}"
}

output "alb_dns_name" {
  value = "${aws_lb.load_balancer.dns_name}"
}

output "lb_target_group" {
  value = "${aws_lb_target_group.front_end.arn}"
}
