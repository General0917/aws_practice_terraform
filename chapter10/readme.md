# 第10章 バッチ
本章のテーマはバッチである。最初にバッチ設計の基本原則について触れ、それを踏まえてECS Scheduled Tasksでバッチを実装する。

## 10.1 バッチ設計
バッチ処理は、オンライン処理とは異なる関心事を有している。アプリケーションレベルでどこまで制御し、ジョブ管理システムでどこまでサポートするかはしっかり設計する必要がある。

### 10.1.1 バッチ設計の基本原則
バッチ設計で重要な観点は「ジョブ管理」、「エラーハンドリング」、「リトライ」、「依存関係制御」の4つである。

#### ジョブ管理
「10.1.2 ジョブ管理」ではジョブの起動タイミングを制御する。

#### エラーハンドリング
エラーハンドリングでは「**エラー通知**」が重要である。なんらかの理由でバッチが失敗した場合、それを検知してリカバリーする必要がある。<br />
また、エラー発生中の「**ロギング**」も重要である。スタックトレースなどの情報は、原因調査で必要になるため、確実にログ出力する。

#### リトライ
バッチ処理が失敗した場合、リトライできなければならない。自動で指定回数をリトライできることが望ましい。少なくとも、手動ではリトライできる必要がある。<br />
リトライできるようにするには、**リトライできるようアプリケーションを設計する**必要がある。当たり前のことを書いているが、手抜きされやすいポイントである。

#### 依存関係制御
ジョブが増えてくると、依存関係制御が必要になる。「ジョブAは必ずジョブBのあとに実行しなければならない」などはよくある。単純に時間をずらして、暗黙的な依存関係を行う場合もあるが、アンチパターンなので避ける。

### 10.1.2 ジョブ管理
バッチは一定の周期で実行されるが、誰かがジョブの起動タイミングを制御しなければならない。それがジョブ管理である。ジョブ管理は、バッチ処理では重要な関心事である。ジョブ管理の仕組みに問題が発生すると、最悪の場合、全ジョブが停止する。

#### cron
ジョブ管理の実装で、最も簡単なのは「**cron**」である。しかし、cronは手軽な反面、きちんと管理するのが難しい。影響範囲の不明な謎のcronが発掘されるなど日常茶飯時である。また、cronで管理されるバッチは大抵、エラーハンドリングやリトライも適当である。依存関係制御もできず、cronを動かすサーバーの運用にも手間がかかる。

#### ジョブ管理システム
システムが成長するとcronはすぐに限界が来る。そこで多くの場合、RundeckやJP1などの「**ジョブ管理システム**」を導入する。ジョブ管理システムはエラー通知やリトライ、依存関係制御の仕組みが組み込まれており、複雑なジョブの管理ができる。ただし、ジョブ管理システムを稼働させるサーバーの運用は、課題として残る。

## 10.2 ECS Scheduled Tasks
「10.1 バッチ設計」で述べたようなジョブ管理システムのマネージドサービスはない。つまり、システムが大きくなるとジョブ管理システムの導入は避けられない。<br />
しかし、あり程度の規模までであれば「**ECS Scheduled Tasks**」を使うことで、ジョブ管理システムの導入を先送りできる。ECS Scheduled Tasksは、ECSのタスクを定期実行する。実装は単純で、CloudWatchイベントからタスクを起動するだけである。<br />
ECS Scheduled Tasks単体では、エラーハンドリングやリトライはアプリケーションレベルで実装する必要があり、依存関係制御もできない。しかし、ジョブ管理サーバーを運用する必要がなく、cronよりもはるかにメンテナンス性が向上する。

### 10.2.1 バッチ用タスク定義
バッチ用のタスク定義から始める。

#### バッチ用CloudWatch Logs
バッチ用CloudWatch Logsをリスト10.1のように定義する。複数のバッチで使いまわすこともできるが、バッチごとに作成した方が運用は楽である。

リスト10.1: バッチ用CloudWatch Logsの定義
```
resource "aws_cloudwatch_log_group" "for_ecs_scheduled_tasks" {
  name = "/ecs-scheduled-tasks/example"
  retention_in_days = 180
}
```

#### バッチ用タスクの定義
次に、バッチ用のタスク定義をリスト10.2のように実装する。コードはリスト9.9とほぼ同じで、差分は7行目のコンテナ定義の部分である。

リスト10.2: バッチ用タスク定義
```
# ECS関連のロールモジュール定義
module "ecs" {
  source = "./ecs"
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
```

#### バッチ用コンテナ定義
コンテナ定義を「batch_container_definitions.json」というファイルに、リスト10.3のように実装する。実装内容な時刻を記録するバッチである。

リスト10.3: バッチ用コンテナ定義
```
[
    {
        "name": "alpine",
        "image": "alpine:latest",
        "essential": true,
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-region": "ap-northeast-1",
                "awslogs-stream-prefix": "batch",
                "awslogs-group": "/ecs-scheduled-tasks/example"
            }
        },
        "command": ["/bin/date"]
    }
]
```

### 10.2.2 CloudWatchイベントIAMロール
リスト10.4のように、CloudWatchイベントからECSを起動するためのIAMロールを作成する。AWSが管理している「**AmazonEC2ContainerServiceEventsRole**」ポリシーを使うと簡単である。このポリシーでは「タスクを実行する」権限と「タスクにIAMロールを渡す」権限を付与する。

リスト10.4: CloudWatchイベントIAMロールの定義
```
module "ecs_events_role" {
    source = "./iam_role"
    name = "ecs-events"
    identifier = "events.amazonaws.com"
    policy = data.aws_iam_policy.ecs_events_role_policy.policy
}

data "aws_iam_policy" "ecs_events_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}
```

### 10.2.3 CloudWatchイベントルール
ジョブの実行スケジュールを定義するため、CloudWatchイベントルールを作成する。リスト10.5のように実装する。

リスト10.5: CloudWatchイベントルールの定義
```
resource "aws_cloudwatch_event_rule" "example_batch" {
  name = "example-batch"
  description = "とても重要なバッチ処理である。"
  schedule_expression = "cron(*/2 * * * ? *)"
}
```

#### 概要
descriptionでは日本語も使える。AWSマネジメントコンソールでの一覧性が向上するため、ひと目で理解できる内容にした方がよい。(図10.1)。

図10.1: タスクのスケジューリング一覧
![](picture/図10_1.png)

#### スケジュール
schedule_expressionは、cron式とrate式をサポートしている。
- **cron式** : 「cron(0 8 * * ? *)」のように記述する。東京リージョンの場合でも、タイムゾーンは**UTC**になる。また、設定の最小精度は1分である。
- **rate式** : 「rate(5 minutes)」のように記述する。単位は『1の場合は単数形、それ以外は複数形』で記載する。つまり、「rate(1 hours)」や「rate(5 hour)」のように記載することができないので、注意が必要である。

### 10.2.4 CloudWatchイベントターゲット
