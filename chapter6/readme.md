# 第6章　ストレージ
本章では、***S3(Simple Storage Service)***について、<br />
「プライベートバケット」、「パブリックバケット」、「ログバケット」の3つのユースケースを題材に学ぶ

## 6.1 プライベートバケット
外部公開しないプライベートバケットから作成する。

### 6.1.1 S3バケット
S3バケットをリスト6.1のように定義する。

リスト6.1: プライベートバケットの定義
```
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
```

#### バケット名
bucketに指定するバケット名は「全世界で一意にしなければならない」という大きな制約がある。<br />
また、DNSの命名規則にも従う必要がある。

#### バージョニング
versioningの設定を有効にすると、オブジェクトを変更・削除しても、いつでも以前のバージョンへ復元できるようになる。多くのユースケースで有利な設定である。

#### 暗号化
server_side_encryption_configurationで暗号化を有効にできる。暗号化を有効化にすると、<br />
オブジェクト保存時に自動で暗号化し、オブジェクト参照時に自動で復号するようになる。<br />
使い勝手が悪くなることもなく、デメリットもほぼない。

### 6.1.2 ブロックパブリックアクセス
ブロックパブリックアクセスを設定すると、予期しないオブジェクトの公開を抑止できる。<br />
既存の公開設定の削除や、新規の公開設定をブロックするなど細かく設定可能である。<br />
特に理由がなければ、リスト6.2のように、すべての設定を有効にする。

リスト6.2: ブロックパブリックアクセスの定義
```
resource "aws_s3_bucket_public_access_block" "private" {
    bucket = aws_s3_bucket.private.id

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}
```

## 6.2 パブリックバケット
外部公開するパブリックバケットは、リスト6.3のように実装する。

リスト6.3: パブリックバケットの定義
```
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
```

## 6.3 ログバケット
AWSの各種サービスがログを保存するためのログバケットを作成する。

### 6.3.1 ログローテーションバケット
ログバケットは、リスト6.4のように実装する。ここでは、第8章で必要になるALBのアクセスログ用のバケットを作成する。<br />
ポイントは、lifecycle_ruleである。ライフサイクルルールを設定することで、180日経過したファイルを自動的に削除し、無限にファイルが増えないようにする。

リスト6.4: ログバケットの定義
```

```

