# ロードバランサーapplyする場合は、最初にchapter7で学習したネットワークを構築する！！
module "vpc" {
    source = "./vpc"
}

# ログバケットの定義
resource "aws_s3_bucket" "alb_log" {
  bucket = "alb-log-pragmatic1-terraform"
}

resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = aws_s3_bucket.alb_log.id

  rule {
    id = "rule-1"
    status = "Enabled"

    expiration {
      days = 180
    }
  }
}

# バケットポリシーの定義
resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect = "Allow"
    actions = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

    principals {
      type = "AWS"
      identifiers = ["582318560864"] # LBを管理しているAWS東京リージョンのアカウントIDを許可
    }
  }
}

resource "aws_lb" "example" {
    name = "example"
    load_balancer_type = "application"
    internal = false
    idle_timeout = 60
    enable_deletion_protection = false

    subnets = [
        module.vpc.aws_subnet_public_0_id,
        module.vpc.aws_subnet_public_1_id
    ]

    access_logs {
        bucket = aws_s3_bucket.alb_log.id
        enabled = true
    }

    security_groups = [
        module.http_sg.security_group_id,
        module.https_sg.security_group_id,
        module.http_redirect_sg.security_group_id
    ]
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
}

module "http_sg" {
    source = "./security_group"
    name = "http_sg"
    vpc_id = module.vpc.vpc_id
    port = 80
    cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
    source = "./security_group"
    name = "https_sg"
    vpc_id = module.vpc.vpc_id
    port = 443
    cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
    source = "./security_group"
    name = "http_redirect_sg"
    vpc_id = module.vpc.vpc_id
    port = 8080
    cidr_blocks = ["0.0.0.0/0"]
}

# ALBの定義
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = "80"
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "これは『HTTP』である。"
        status_code = "200"
      }
    }
}

# route 53(DNS)のzoneと、レコード定義
data "aws_route53_zone" "example" {
  name = "sample0917.com"
}

resource "aws_route53_zone" "test_example" {
  name = "testexample0917.com"
}

resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.example.zone_id
  name = data.aws_route53_zone.example.name
  type = "A"

  alias {
    name = aws_lb.example.dns_name
    zone_id = aws_lb.example.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.example.name
}

# SSL証明書の定義
resource "aws_acm_certificate" "example" {
  domain_name = aws_route53_record.example.name
  subject_alternative_names = []
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# SSL証明書の検証用レコードの定義
resource "aws_route53_record" "example_certificate" {
  for_each = {
    for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      record = dvo.resource_record_value
      type = dvo.resource_record_type
    }
  }
  name = each.value.name
  type = each.value.type
  records = [each.value.record]
  zone_id = data.aws_route53_zone.example.id
  ttl = 60
}

# SSL証明書の検証完了までの待機
resource "aws_acm_certificate_validation" "example" {
  certificate_arn = aws_acm_certificate.example.arn
  validation_record_fqdns = [for record in aws_route53_record.example_certificate : record.fqdn]
}

# HTTPSリスナーの定義
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example.arn
  port = "443"
  protocol = "HTTPS"
  certificate_arn = aws_acm_certificate.example.arn
  ssl_policy = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTPS』である。"
      status_code = "200"
    }
  }
}

# HTTPからHTTPSにリダイレクトするリスナーの定義
resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.example.arn
  port = "8080"
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ターゲットグループの定義
resource "aws_lb_target_group" "example" {
  name = "example"
  target_type = "ip"
  vpc_id = module.vpc.vpc_id
  port = 80
  protocol = "HTTP"
  deregistration_delay = 300

  health_check {
    path = "/"
    healthy_threshold = 5
    unhealthy_threshold = 2
    timeout = 5
    interval = 30
    matcher = 200
    port = "traffic-port"
    protocol = "HTTP"
  }

  depends_on = [aws_lb.example]
}

# リスナールールの定義
resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.https.arn
  priority = 100

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}