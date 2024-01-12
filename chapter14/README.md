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
Dockerイメージをプッシュする際には、まずDockerクライアントを認証する。
認証する際は、リージョンの変数を定義する必要があるので、変数が定義されていない場合は、変数を定義する。
```
# XXXXXはアカウントIDを入力する

$ aws ecr get-login-password --region "ap-northeast-1" | docker login --username AWS --password-stdin XXXXX.dkr.ecr.ap-northeast-1.amazonaws.com

Login Succeeded
```

次にイメージ名のレジストリをECRにして、適当なDockerfileをビルドする。
```
$ docker build -t XXXXX.dkr.ecr.ap-northeast-1.amazonaws.com/example:latest .
```

あとは、通常通り、Dockerイメージをプッシュする。
```
$ docker push XXXXX.dkr.ecr.ap-northeast-1.amazonaws.com/example:latest
```

ECR内のリポジトリを確認すると、イメージがプッシュされていることが確認できる。
![](picture/Docker_image_push_complete.png)

## 14.3 継続的インテグレーション
AWSでは、継続的インテグレーション(CI)サービスとしてCodeBuildが提供されている。本書では「Dockerイメージのビルド」と「ECRへのプッシュ」をCodeBuildで行う。

### 14.3.1 CodeBuildサービスロール
CodeBuildが使用するIAMロールを作成する。

#### ポリシードキュメント
ポリシードキュメントをリスト14.3のように定義し、次のような権限を付与する。
 - ビルド出力アーティファクトを保存するためのS3操作権限
 - ビルドログを出力するためのCloudWatch Logsの操作権限
 - DockerイメージをプッシュするためのECR操作権限

なお、ビルド出力アーティファクトとは、CodeBuildがビルド時に生成した成果物となるファイルのことである。

リスト14.3: CodeBuildサービスロールのポリシードキュメントの定義
```
data "aws_iam_policy_document" "codebuild" {
  statement {
    effect = "Allow"
    resources = ["*"]

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
  }
}
```

#### IAMロール
CodeBuild用のIAMロールを、リスト14.4のように実装する。identifierには「codebuild.amazonaws.com」を指定し、このIAMロールをCodeBuildで使うことを宣言する。

リスト14.4: CodeBuildサービスロールの定義
```
module "codebuild_role" {
  source = "./iam_role"
  name = "codebuild"
  identifier = "codebuild.amazonaws.com"
  policy = data.aws_iam_policy_document.codebuild.json
}
```

### 14.3.2 CodeBuildプロジェクト
リスト14.5のように、CodeBuildプロジェクトを作成する。なお、このCodeBuildプロジェクトは「14.4.4 CodePipeline」から起動するよう、のちほど設定する。

リスト14.5: CodeBuildプロジェクトの定義
```
resource "aws_codebuild_project" "example" {
  name = "example"
  service_role = module.codebuild_role.iam_role_arn

  source {
    type = "CODEPIPELINE"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/standard:2.0"
    privileged_mode = true
  }
}
```

#### サービスロール
service_roleに、リスト14.4で作成したIAMロールを指定する。

#### ソースとアーティファクト
ビルド対象のファイルをsourceで指定する。また、ビルド出力アーティファクトの格納先をartifactsで指定する。両方とも「CODEPIPELINE」と指定することで、CodePipelineと連携することを宣言する。

#### ビルド環境
imageに指定しているaws/codebuild/standard:2.0は、AWSが管理しているUbuntuベースのイメージである。このイメージを使う場合、「14.3.3 ビルド仕様」でランタイムバージョンの指定が必要になる。<br />
また、ビルド時にdockerコマンドを使うため、privileged_modeをtrueにして、特権を付与する。

### 14.3.3 ビルド仕様
CodeBuildのビルド処理を規定するのが「**buildspec.yml**」である。buildspec.ymlは、次のようにアプリケーションコードのプロジェクトルールに配置する。
![](picture/CodeBuild_Project_Rule.png)

たとえば、リスト14.6のbuildspec.ymlには4フェーズを定義している。
1. **install** : 使用するDockerのランタイムバージョンを指定
2. **pre_build** : ECRにログイン
3. **build** : Dockerイメージのビルドとプッシュ
4. **post_build** : 「imagedefinitions.json」ファイルの作成

なお、18行目のimagedefinitions.jsonについては、「14.4.4 CodePipeline」で触れる。

リスト14.6: buildspec.ymlの定義

## 14.4 継続的デリバリー
アプリケーションコードがGitHubのmasterブランチにマージされたら、自動的にECSへデプロイされる仕組みを構築する。

### 14.4.1 CodePipelineサービスロール
CodePipelineが使用するIAMロールを作成する。

#### ポリシードキュメント
ポリシードキュメントをリスト14.7のように定義し、次のような権限を付与する。
- ステージ間でデータを受け渡すためのS3操作権限
- 「14.3.2 CodeBuildプロジェクト」を起動するためのCodeBuild操作権限
- ECSにDockerイメージをデプロイするためのECS操作権限
- CodeBuildやECSにロールを渡すためのPassRole権限

リスト14.7: CodePipelineサービスロールのポリシードキュメントの定義
```
data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect = "Allow"
    resources = ["*"]

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "iam:PassRole",
    ]
  }
}
```

#### IAMロール
CodePipeline用のIAMロールを、リスト14.8のように実装する。identifierには「codepipeline.amazonaws.com」を指定し、このIAMロールをCodePipelineで使うことを宣言する。

リスト14.8: CodePipelineサービスロールの定義
```
module "codebuild_role" {
  source = "./iam_role"
  name = "codepipeline"
  identifier = "codepipeline.amazonaws.com"
  policy = data.aws_iam_policy_document.codepipeline.json
}
```

### 14.4.2 アーティファクトストア
CodePipelineの各ステージで、データの受け渡しに使用するアーティファクトストアを作成する。リスト14.9のように実装する。

リスト14.9: アーティファクトストアの定義
```
# アーティファクトストアの定義
resource "aws_s3_bucket" "artifact" {
  bucket = "artifact-pragmatic-terraform"
}

resource "aws_s3_bucket_lifecycle_configuration" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  rule {
    id = "rule-1"
    status = "Enabled"

    expiration {
      days = 180
    }
  }
}
```

### 14.4.3 GitHubトークン
「14.4.4 CodePipeline」と「14.4.7 GitHub Webhook」で必要になるGitHubトークンを作成する。まず、GitHubのPersonal access tokens画面を開き、「Generate new token」をクリックし、「Generate new token(classic)」をクリックする。

図14.2: GitHubのPersonal access tokens画面
![](picture/図14_2.png)

次に「Note」に説明を入力し、「**repo**と**admin:repo_hook**」にチェックを入れて、スコープを設定する(図14.3)。最後に下へスクロールして「Generate token」をクリックする。

図14.3: スコープ設定画面
![](picture/図14_3.png)

生成されたGitHubトークンをコピーする(図14.4)。

図14.4: GitHubトークンのコピー
![](picture/図14_4.png)

コピーしたGitHubトークンを変数「GITHUB_TOKEN」に設定する。
```
$GITHUB_TOKEN="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"
```

### 14.4.4 CodePipeline
CodePipelineは複数のステージから構成される。リスト14.10では3つ実装する。\
1. **Sourceステージ** : GitHubからソースコードを取得する
2. **Buildステージ** : CodeBuildを実行し、ECRにDockerイメージをプッシュする
3. **Deployステージ** : ECSへDockerイメージをデプロイする

リスト14.10: CodePipelineの定義
```
module "ecs" {
  source = "./ecs"
}

data "aws_ssm_parameter" "github_token" {
  name = "/continuous_apply/github_token"
}

resource "aws_codepipeline" "example" {
  name = "example"
  role_arn = module.codepipeline_role.iam_role_arn

  stage {
    name = "Source"

    action {
      name = "Source"
      category = "Source"
      owner = "ThirdParty"
      provider = "GitHub"
      version = 1
      output_artifacts = ["Source"]

      configuration = {
        Owner = "General0917"
        Repo = "aws_practice_terraform"
        Branch = "master"
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Build"

    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = 1
      input_artifacts = ["Source"]
      output_artifacts = ["Build"]

      configuration = {
        ProjectName = aws_codebuild_project.example.id
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name = "Deploy"
      category = "Deploy"
      owner = "AWS"
      provider = "ECS"
      version = 1
      input_artifacts = ["Build"]

      configuration = {
        ClusterName = module.ecs.aws_ecs_cluster_name
        ServiceName = module.ecs.aws_ecs_service_name
        FileName = "imagedefinitions.json"
      }
    }
  }

  artifact_store {
    location = aws_s3_bucket.artifact.id
    type = "S3"
  }
}
```

#### Sourceステージ
5~23行目のSourceステージでは、ソースコードの取得先となるGitHubリポジトリとブランチを指定する。なお、CodePipelineの起動はWebhookから行うため、20行目のようにPollForSourceChangesをfalseにしてポーリングは無効にする。

#### Buildステージ
25~41行目のBuildステージでは、リスト14.5で実装したCodeBuildを指定する。

#### Deployステージ
43~60行目のDeployステージでは、デプロイ先のECSクラスタとECSサービスを指定する。Deployステージで重要なのが、57行目の「imagedefinitions.json」である。これは、リスト14.6のbuildspec.ymlの最後に作成しているJSONファイルである。このJSONファイルには、リスト14.11のような内容が記述されている。

リスト14.11: imagedefinitions.jsonの中身
```
[
    {
        "name": "example",
        "imageUri": "your-repository-uri:latest"
    }
]
```

このJSONは、リスト9.3で実装したコンテナ定義の一部である。CodePipelineではnameで指定したコンテナを、imageUriに指定したイメージで更新する。なおECS Fargateの場合、latestタグでも必ずdocker pullするため、デプロイごとにタグを変更する必要はない。

#### アーティファクトストア
artifact_storeには、リスト14.9で作成したS3バケットを指定する。

### 14.4.5 CodePipeline Webhook
GitHubからWebhookを受け取るためにCodePipeline Webhookを作成する。CodePipeline Webhookは、リスト14.12のように実装する。

リスト14.12: CodePipeline Webhookの定義
```
resource "random_id" "sample" {
  keepers = {
    codepipeline_name = aws_codepipeline.example.name
  }

  byte_length = 32
}

resource "aws_codepipeline_webhook" "example" {
  name = "example"
  target_pipeline = aws_codepipeline.example.name
  target_action = "Source"
  authentication = "GITHUB_HMAC"

  authentication_configuration {
    secret_token = random_id.sample.hex
  }

  filter {
    json_path = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}

output "random_id_output" {
  value = random_id.sample.hex
}
```

#### ターゲット
Webhookを受け取ったら起動するパイプラインをtarget_pipelineで設定する。ここではリスト4.10で作成したCodePipelineを指定する。<br />
また、最初に実行するアクションをtarget_actionで指定する。

#### 認証
GitHubのWebhookはHMACによるメッセージ認証をサポートしている。まずauthenticationに「GITHUB_HMAC」を指定する。<br />
次にauthentication_configurationのsecret_tokenへ、20バイト以上のランダムな文字列を秘密鍵として指定する。文字列生成は、random_idリソースを使用して生成する。この秘密鍵は「14.4.7 GitHub Webhook」でも使用する。<br />
なお、**秘密鍵はtfstateファイルに平文で書き込まれる。**これは「13.1.4 DBインスタンス」のマスターパスワードと同様の挙動である。どうしてもtfstateファイルへの書き込みを回避したい場合、Terraformでの管理を断念するしかない。

#### フィルタ
CodePipelineの起動条件はfilterで設定する。リスト14.12では、リスト14.10の19行目で指定したmasterブランチのときのみ起動するよう設定している。

### 14.4.6 GitHubプロバイダ
「14.4.7 GitHub Webhook」では、GitHubのリソースを操作する。そこで、リスト14.13のようにGitHubプロバイダを定義する。<br />
なおGitHubのクレデンシャルは、「14.4.3 GitHubトークン」で設定した変数「GITHUB_TOKEN」が自動的に使用される。

リスト14.13: GitHubプロバイダの定義
```
provider "github" {
  owner = "General0917"
  token = "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"
}
```

### 14.4.7 GitHub Webhook
GitHub上でのイベントを検知し、コードの変更を通知するGitHub Webhookを、リスト14.14のように定義する。CodePipelineではWebhookのリソースを、通知する側・される側のそれぞれで実装する。

リスト14.14: GitHub Webhookの定義
```
resource "github_repository_webhook" "example" {
  repository = "aws_practice_terraform"

  configuration {
    url = aws_codepipeline_webhook.example.url
    secret = random_id.sample.hex
    content_type = "json"
    insecure_ssl = false
  }

  events = ["push"]
}
```

#### 通知設定
configurationで、通知先となるCodePipelineのURLや、HMAC用の秘密鍵を指定する。6行目の「secret」とリスト14.12の「secret_token」は同じ値を入れる必要がある。

#### イベント
eventsで、トリガーとなるイベントを設定する。リスト14.14では「push」のみ指定しているが、他に「pull_request」なども指定可能である。