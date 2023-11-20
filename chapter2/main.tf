resource "aws_instance" "example" {
  ami = "ami-014886dca6bd4bce2"
  instance_type = "t3.micro"

  tags = {
    "Name" = "example"
  }

  user_data = <<EOF
  #!/bin/bash
  yum install -y httpd
  systemctl start httpd.service
EOF
}