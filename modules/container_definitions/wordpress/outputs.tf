output "name" {
  value = "wordpress"
}
output "json" {
  value = "${module.task_definition_creator.json}"
}
