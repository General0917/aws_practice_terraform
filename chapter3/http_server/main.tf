variable "instance_type" {
  
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

resource "aws_instance" "default" {
  # ami = data.aws_ami.ubuntu.id
  ami = "ami-014886dca6bd4bce2"
  vpc_security_group_ids = [aws_security_group.default.id]
  instance_type = var.instance_type

  user_data = <<EOF
  #!/bin/bash
  yum install -y httpd
  systemctl start httpd.service
EOF
}

resource "aws_security_group" "default" {
  name = "ec2"

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

output "public_dns" {
    value = aws_instance.default.public_dns
}