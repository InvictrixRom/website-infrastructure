output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "public_subnet_id" {
  value = "${aws_subnet.public_subnet.id}"
}

output "ecs_ami" {
  value = "${data.aws_ami.ecs_ami.id}"
}

output "cluster_name" {
  value = "${aws_ecs_cluster.cluster.name}"
}

output "cluster_arn" {
  value = "${aws_ecs_cluster.cluster.arn}"
}

output "cluster_id" {
  value = "${aws_ecs_cluster.cluster.id}"
}

output "eip_id" {
  value = "${aws_eip.eip.id}"
}
