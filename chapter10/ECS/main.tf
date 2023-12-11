/*
module "loadbalancer" {
  source = "./loadbalancer"
}

# ECSクラスタの定義
resource "aws_ecs_cluster" "example" {
  name = "example"
}

# タスク定義
# resource "aws_ecs_task_definition" "example" {
#   family = "example"
#   cpu = "256"
#   memory = "512"
#   network_mode = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   container_definitions = file("./container_definitions.json")
# }

# タスク定義にECSタスク実行IAMロールを追加
resource "aws_ecs_task_definition" "example" {
  family = "example"
  cpu = "256"
  memory = "512"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = file("./container_definitions.json")
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
}

resource "aws_ecs_service" "example" {
  name = "example"
  cluster = aws_ecs_cluster.example.arn
  task_definition = aws_ecs_task_definition.example.arn
  desired_count = 2
  launch_type = "FARGATE"
  platform_version = "1.3.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = true
    security_groups = [module.nginx_sg.security_group_id]

    subnets = [
        module.loadbalancer.aws_subnet_private_0_id,
        module.loadbalancer.aws_subnet_private_1_id
    ]
  }

  load_balancer {
    target_group_arn = module.loadbalancer.aws_lb_target_group_example_arn
    container_name = "example"
    container_port = 80
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "nginx_sg" {
    source = "./security_group"
    name = "nginx-sg"
    vpc_id = module.loadbalancer.vpc_id
    port = 80
    cidr_blocks = [module.loadbalancer.aws_vpc_example_cidr_block]
}

output "alb_dns_name" {
  value = module.loadbalancer.alb_dns_name
}

output "domain_name" {
  value = module.loadbalancer.domain_name
}

# CloudWatch Logsの定義
resource "aws_cloudwatch_log_group" "for_ecs" {
  name = "/ecs/example"
  retention_in_days = 180
}
*/

# AmazonECSTaskExecutionRolePolicyの参照
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECSタスク実行IAMロールのポリシードキュメントの定義
data "aws_iam_policy_document" "ecs_task_execution" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "kms:Decrypt",
    ]
    resources = ["*"]
  }

  source_policy_documents = [data.aws_iam_policy.ecs_task_execution_role_policy.policy]
}

# ECSタスク実行IAMロールの定義
module "ecs_task_execution_role" {
  source = "../iam_role"
  name = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com"
  policy = data.aws_iam_policy_document.ecs_task_execution.json
}

output "aws_iam_policy_document_ecs_task_execution" {
    value = module.ecs_task_execution_role.iam_role_arn
}