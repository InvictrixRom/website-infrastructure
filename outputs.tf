output "DNSName" {
  value = "${module.alb.alb_dns_name}"
}

output "mysql_password" {
  value = "${data.terraform_remote_state.state.mysql_password}"
}
