# Creating a NAT instance
data "aws_ami" "ec2_nat" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_iam_role" "ec2_nat_instance_policy" {
  name = "${var.prefix}_ec2_nat_instance_policy"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_policy_attachment" "ec2_instance_policy" {
  name  = "${var.prefix}_ec2_nat_instance_policy"
  roles = [aws_iam_role.ec2_nat_instance_policy.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile_tf" {
  name = "${var.prefix}_ec2_nat_instance_profile"
  role = aws_iam_role.ec2_nat_instance_policy.name
}

resource "aws_security_group" "nat_instance" {
  name        = "${var.prefix}_ec2_nat_instance_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "NatInstance" {
  count = var.az_count
  ami                         = data.aws_ami.ec2_nat.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public[count.index].id
  associate_public_ip_address = "true"
  source_dest_check           = "false"
  vpc_security_group_ids      = [aws_security_group.nat_instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile_tf.id
  user_data                   = <<EOF
#!/bin/bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo service sshd stop
sudo systemctl stop rpcbind
  EOF

  tags = {
    Name = "${var.prefix}_nat_instance"
  }
}