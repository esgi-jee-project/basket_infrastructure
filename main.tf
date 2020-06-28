provider "aws" {
    profile = "default"
    region = "eu-west-3"
}

module "api" {
  source = "./modules/ecs_ec2"
  prefix = var.prefix
  private_subnet = aws_subnet.private
  public_subnet = aws_subnet.public
  availability_zone = data.aws_availability_zones.available.names
  az_count = var.az_count
  task_definition_path = "${path.module}/conf/api/task_definitions_service.json"
  vpc = aws_vpc.main
  container_env = var.container_env
}

output "api_app_url" {
  value = module.api.alb_hostname
  description = "The url for the api"
}
