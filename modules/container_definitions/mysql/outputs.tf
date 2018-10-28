output "name" {
  value = "mysql"
}

output "json" {
  value = "${module.task_definition_creator.json}"
}
