# 第14章 デプロイメントパイプライン
継続的にシステムを変更するためには、デプロイの仕組みが欠かせない。本章ではCodePipelineを中心にデプロイメントパイプラインを構築し、ECSへデプロイする方法を学習する。

## 14.1 デプロイメントパイプラインの設計
前提として、アプリケーションコードはGitHubで管理する。<br />
GitHubにコードをpushして、ECSへコンテナをデプロイする流れは以下のとおりである。(図14.1)
1. GitHubのWebhookで変更を検知
2. GitHubからソースコードを取得
3. Dockerイメージをビルドしてコンテナレジストリへpush
4. コンテナレジストリからDockerイメージをpullしてECSへデプロイ

図14.1: デプロイメントパイプラインの構成
![](picture/図14_1.png)

## 14.2 コンテナレジストリ
まずはDockerイメージを保管するコンテナレジストリを作成する。AWSで**ECR(Elastic Container Registry)**というマネージドサービスが提供されているので、これを利用する。

### 14.2.1 ECRリポジトリ
Dockerイメージを保管するECRリポジトリを、リスト14.1のように実装する。

リスト14.1: ECRリポジトリの定義
```
resource "aws_ecr_repository" "example" {
  name = "example"
}
```

### 14.2.2 ECRライフサイクルポリシー
ECRリポジトリに保存できるイメージの数には限りがある。そのため、イメージが増えすぎないようにする。<br />
たとえば、リスト14.2では「release」で始まるイメージタグを30個までに制限している。<br />
ライフサイクルポリシーではさまざまなポリシーが設定できる。詳細は、AWSの公式ドキュメントを参照。

リスト14.2: ECRライフサイクルポリシーの定義
```
resource "aws_ecr_lifecycle_policy" "example" {
  repository = aws_ecr_repository.example.name

  policy = <<EOF
  {
    "rules" : [
        {
            "rulePriority" :1,
            "description" : "Keep last 30 release tagged images",
            "selection" : {
                "tagStatus" : "tagged",
                "tagPrefixList" : ["release"],
                "countType" : "imageCountMoreThan",
                "countNumber" : 30
            },
            "action" : {
                "type" : "expire"
            }
        }
    ]
  }
  EOF
}
```

### 14.2.3 Dockerイメージのpush
