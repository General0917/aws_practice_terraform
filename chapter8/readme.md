# 第8章 ロードバランサーとDNS
本章では**ALB(Application Load Balancer)**を学ぶ。あわせて**Route 53**と**ACM(AWS Certificate Manager)**を使い、HTTPSでアクセスできるよう設定する。

## 8.1 ALBの構成要素
ALBはAWSが提供するロードバランサーである。ALBはクロスゾーン負荷分散に標準で対応しており、複数のアベイラビリティゾーンのバックエンドサーバーに、リクエストを振り分けられる。HTTPSの終端やECS Fargateとの連携もサポートされている。ALBは図8.1のように、複数のリソースで構成される。

図8.1: ALBの構成要素
![](picture/図8_1.png)

リスナーに定義したポートでリクエストを受け付け、パスなどの一定のルールに基づき、ロードバランサーの背後にいるターゲットへリクエストを転送する。本書では、最終的に、ALBで受け取ったリクエストは、第9章で学ぶECSへ振り分ける。

## 8.2 HTTP用ロードバランサー
まずはHTTPアクセス可能なALBを作成する。なお、ALBを配置するネットワークは第7章のものを使用する。以降の章でも、注記することなくこのリソースを使う。

### 8.2.1 アプリケーションロードバランサー
最初にアプリケーションロードバランサーを、リスト8.1のように定義する。

リスト8.1: アプリケーションロードバランサーの定義
```
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
      identifiers = ["582318560864"] # LBが管理しているAWS東京リージョンのアカウントIDを許可
    }
  }
}

resource "aws_lb" "example" {
    name = "example"
    load_balancer_type = "application"
    internal = false
    idle_timeout = 60
    enable_deletion_protection = true

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
```

32、33行目のsubnetsを定義する際は、moduleから値を取得しているが、moduleから値を取得する際には、vpcを構築するリソースから**output**構文を取得し、値を呼びだすようにする！！<br />
これは、Terraformの仕様で外部moduleから値を取得する際に利用される。

#### 名前と種別
名前はnameで設定する。また、種別をload_balancer_typeで設定する。aws_lbリソースはALBだけでなく、<br />
***NBL(Network Load Balancer)***も作成できる。「application」を指定するとALB、「network」を指定するとNLBになる。

#### Internal
ALBが「インターネット向け」なのか「VPC内部向け」なのかを指定する。インターネット向けの場合は、internalをfalseにする。

#### タイムアウト
idle_timeoutは秒単位で指定する。タイムアウトのデフォルト値は60秒である。

#### 削除保護
enable_deletion_protectionをtrueにすると、削除保護が有効になる。本番環境では誤って削除しないよう、有効にしておく。

#### サブネット
ALBが所属するサブネットをsubnetsで指定する。異なるアベイラビリティゾーンのサブネットを指定して、クロスゾーン負荷分散を実現する。

#### アクセスログ
access_logsにバケット名を指定すると、アクセスログの保存が有効になる。ここでは、第6章のリスト6.4で作成したS3バケットを指定する。

#### セキュリティグループ
セキュリティグループをリスト8.2のように定義する。HTTPの80番ポートとHTTPSの443番ポートに加えて、「8.5.2 HTTPのリダイレクト」で使用する8080番ポートも許可する。そして、リスト8.1のsecurity_groupsに、これらのセキュリティグループを設定する。

リスト8.2: アプリケーションロードバランサーのセキュリティグループの定義
```
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
```
vpc_idも同様に、vpcを構築するリソースから**output**構文を取得し、値を呼びだすようにする！！

### 8.2.2 リスナー
リスナーで、どのポートのリクエストを受け付けるか設定する。リスナーはALBに複数アタッチ可能。リスナーはリスト8.3のように定義する。

リスト8.3: HTTPリスナーの定義
```
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
```

#### ポート番号
portには1~65535の値が設定可能。ここではHTTPなので「80」を指定する。

#### プロトコル
ALBは「HTTP」と「HTTPS」のみサポートしており、protocolで指定する。

#### デフォルトアクション
リスナーは複数のルールを設定して、異なるアクションを実行可能である。もし、いずれのルールにも合致しない場合は、default_actionが実行される。定義できるアクションにはいくつかあるが、ここでは3つ紹介する。
- **forward** : リクエストを別ターゲットグループに転送
- **fixed-response** : 固定のHTTPレスポンスを応答
- **redirect** : 別のURLにリダイレクト

### 8.2.3 HTTPアクセス
リスト8.1からリスト8.3をapplyする。

```
$ terraform apply -auto-approve

alb_dns_name = example-1288450637.ap-northeast-1.elb.amazonaws.com

$ curl example-1288450637.ap-northeast-1.elb.amazonaws.com


StatusCode        : 200
StatusDescription : OK
Content           : これは『HTTP』である。
RawContent        : HTTP/1.1 200 OK
                    Connection: keep-alive
                    Content-Length: 31
                    Content-Type: text/plain; charset=utf-8
                    Date: Fri, 01 Dec 2023 19:43:50 GMT
                    Server: awselb/2.0

                    これは『HTTP』である。
Forms             : {}
Headers           : {[Connection, keep-alive], [Content-Length, 31], [Content-Type, text/plain; charset=utf-8], [Date, Fri, 01 Dec 2023 19:43:50 GMT]...}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : System.__ComObject
RawContentLength  : 31
```

## 8.3 Route 53
Route 53は、AWSが提供する**DNS(Domain Name System)**のサービスである。

### 8.3.1 ドメインの登録
AWSマネジメントコンソールから次の手続きを行うと、ドメインの登録ができる。