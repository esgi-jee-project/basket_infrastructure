resource "aws_ecr_repository" "back_end" {
  name                 = var.prefix
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "back_end" {
  name = var.prefix
}

resource "aws_iam_role" "back_end_elastic_container" {
  name = "${var.prefix}-elastic-container"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "back_end_elastic_container" {
  name = "${var.prefix}-elastic-container"
  role = aws_iam_role.back_end_elastic_container.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "ec2:DescribeTags",
            "ecs:CreateCluster",
            "ecs:DeregisterContainerInstance",
            "ecs:DiscoverPollEndpoint",
            "ecs:Poll",
            "ecs:RegisterContainerInstance",
            "ecs:StartTelemetrySession",
            "ecs:UpdateContainerInstancesState",
            "ecs:Submit*",
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "back_end_ec2" {
  name = "${var.prefix}-ec2"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "back_end_ec2" {
  name = "${var.prefix}-ec2"
  role = aws_iam_role.back_end_ec2.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "ec2:DescribeTags",
          "ecs:CreateCluster",
          "ecs:DeregisterContainerInstance",
          "ecs:DiscoverPollEndpoint",
          "ecs:Poll",
          "ecs:RegisterContainerInstance",
          "ecs:StartTelemetrySession",
          "ecs:UpdateContainerInstancesState",
          "ecs:Submit*",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

data "aws_ami" "latest_ecs" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name   = "name"
        values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

data "template_file" "ec2_ecs_definition" {
  template = "${file("${path.module}/ecs_data.script")}"

  vars = {
    cluster_name = var.prefix
  }
}

resource "aws_iam_instance_profile" "profile" {
  name = var.prefix
  role = aws_iam_role.back_end_ec2.name
}


resource "aws_instance" "back_end" {
  count = var.az_count
  ami = data.aws_ami.latest_ecs.id
  availability_zone = element(var.availability_zone, count.index)
  subnet_id = element(var.private_subnet.*.id, count.index)
  iam_instance_profile = aws_iam_instance_profile.profile.name
  instance_type = "t2.micro"
  ebs_optimized = "false"
  source_dest_check = "false"
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.back_end_ec2_ssh.id]
  user_data = data.template_file.ec2_ecs_definition.rendered
  root_block_device {
    volume_type = "gp2"
    volume_size = "30"
    delete_on_termination = "true"
  }

  tags = {
    Name = "${var.prefix}-instance"
  }
}

data "template_file" "back_end_task_definition_ecs" {
  template =  file(var.task_definition_path)

  vars = merge({
    app_port = var.app_port 
    image = "${aws_ecr_repository.back_end.repository_url}:latest"
  }, var.container_env)
}

resource "aws_ecs_task_definition" "back_end" {
  family                = var.prefix
  container_definitions = data.template_file.back_end_task_definition_ecs.rendered
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  memory                   = "256"
  execution_role_arn = aws_iam_role.back_end_elastic_container.arn
  task_role_arn = aws_iam_role.back_end_elastic_container.arn
}

resource "aws_ecs_service" "back_end" {
  name            = var.prefix
  cluster         = aws_ecs_cluster.back_end.id
  task_definition = aws_ecs_task_definition.back_end.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    security_groups  = [aws_security_group.back_end_ecs.id]
    subnets          = var.private_subnet.*.id
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.back_end.id
    container_name   = var.prefix
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.back_end, aws_instance.back_end]
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "/ecs/${var.prefix}"
}

resource "aws_cloudwatch_log_stream" "cb_log_stream" {
  name           = "ecs_ec2"
  log_group_name = aws_cloudwatch_log_group.log_group.name
}