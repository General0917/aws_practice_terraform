provider "aws" {
  region = "ap-northeast-3"
}

/*
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
*/

/*
variable "example_instance_type" {
  default = "t3.micro"
}
*/

/*
locals {
  example_instance_type = "t3.micro"
}
*/

/*
output "example_instance_id" {
  value = aws_instance.example.id
}
*/

/*
resource "aws_instance" "example" {
  # ami = data.aws_ami.ubuntu.id
  ami = "ami-014886dca6bd4bce2"
  instance_type = var.example_instance_type
  # instance_type = local.example_instance_type
  vpc_security_group_ids = [aws_security_group.example_ec2.id]

  #   tags = {
  #   "Name" = "example"
  # }

  
  # user_data = <<EOF
  # #!/bin/bash
  # yum install -y httpd
  # systemctl start httpd.service
  # EOF

  user_data = file("./user_data.sh")
}
*/

/*
output "example_public_dns" {
  value = aws_instance.example.public_dns
}
*/

/*
resource "aws_security_group" "example_ec2" {
  name = "example-ec2"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
*/

module "web_server" {
  source = "./http_server"
  instance_type = "t3.micro"
}

output "public_dns" {
  value = module.web_server.public_dns
}