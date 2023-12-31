# private用のバケット定義
resource "aws_s3_bucket" "private" {
    bucket = "private-pragmatic1-terraform"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
    bucket = aws_s3_bucket.private.id
    versioning_configuration {
        status = "Enabled"
    }

}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
    bucket = aws_s3_bucket.private.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

resource "aws_s3_bucket_public_access_block" "private" {
    bucket = aws_s3_bucket.private.id

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

# パブリックバケットの定義
resource "aws_s3_bucket" "public" {
  bucket = "public-pragmatic1-terraform"
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.public.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.public.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_cors_configuration" "example" {
    bucket = aws_s3_bucket.public.id

    cors_rule {
        allowed_origins = ["https://example.com"]
        allowed_methods = ["GET"]
        allowed_headers = ["*"]
        max_age_seconds = 3000
    }
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.public.id
  acl    = "public-read"
  
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
    aws_s3_bucket_cors_configuration.example
  ]
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

# S3バケットの強制削除
resource "aws_s3_bucket" "force_destroy" {
  bucket = "force-destroy-pragmatic1-terraform"

  force_destroy = true
}