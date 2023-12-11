# ECS関連のロールモジュール定義
module "ecs" {
  source = "./ecs"
}

# バッチ用CloudWatch Logsの定義
resource "aws_cloudwatch_log_group" "for_ecs_scheduled_tasks" {
  name = "/ecs-scheduled-tasks/example"
  retention_in_days = 180
}

# バッチ用タスクの定義
resource "aws_ecs_task_definition" "example_batch" {
  family = "example-batch"
  cpu = 256
  memory = 512
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = file("./batch_container_definitions.json")
  execution_role_arn = module.ecs.aws_iam_policy_document_ecs_task_execution
}

# CloudWatchイベントIAMロールの定義
module "ecs_events_role" {
    source = "./iam_role"
    name = "ecs-events"
    identifier = "events.amazonaws.com"
    policy = data.aws_iam_policy.ecs_events_role_policy.policy
}

data "aws_iam_policy" "ecs_events_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

# CloudWatchイベントルール
resource "aws_cloudwatch_event_rule" "example_batch" {
  name = "example-batch"
  description = "とても重要なバッチ処理である。"
  schedule_expression = "cron(*/2 * * * ? *)"
}