# private用のバケット定義
resource "aws_s3_bucket" "private" {
    bucket = "private-pramatic-terraform"
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
  bucket = "public-pramatic-terraform"
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