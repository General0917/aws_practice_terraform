output "vpc_id" {
    value = aws_vpc.example.id
}

output "aws_subnet_public_0_id" {
    value = aws_subnet.public_0.id
}

output "aws_subnet_public_1_id" {
    value = aws_subnet.public_1.id
}

output "aws_subnet_private_0_id" {
    value = aws_subnet.private_0.id
}

output "aws_subnet_private_1_id" {
    value = aws_subnet.private_1.id
}

output "aws_vpc_example_cidr_block" {
    value = aws_vpc.example.cidr_block
}