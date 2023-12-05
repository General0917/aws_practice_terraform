# 第9章 コンテナオーケストレーション
本章ではコンテナオーケストレーションサービスの **ECS(Elastic Container Service)** について学ぶ。AWSでは **EKS(Elastic Kubernetes Service)** も有名であるが、ECSはシンプルで敷居が低いため、本章ではECSを採用する。

## 9.1 ECSの構成要素
ECSは複数のコンポーネントを組み合わせて実装する(図9.1)。ホストサーバーを束ねる「ECSクラスタ」、コンテナの実行単位となる「タスク」、タスクを長期稼働させてALBとのつなぎ役にもなる「ECSサービス」などある。

図9.1: ECSの構成要素
![](picture/図9_1.png)

## 9.2 ECSの起動タイプ
ECSには「EC2起動タイプ」と「Fargate起動タイプ」が存在する。

### 9.2.1 EC2起動タイプ
EC2起動タイプでは、ホストサーバーへSSHログインしてデバッグしたり、SpotFleetを併用してコスト削減を図ることが可能である。その半面、ホストサーバーの管理が必要なため、運用はやや煩雑である。

### 9.2.2 Fargate起動タイプ
Fargate起動タイプは、ホストサーバーの管理が不要で運用は楽である。その反面、SSHログインはできないため、デバッグの難易度は上がる。本章では、運用が楽なFargate起動タイプで実装する。

## 9.3 Webサーバーの構築
ここでは、ECSをプライベートネットワークに配置し、nginxコンテナを起動する。ALB経由でリクエストを受け取り、それをECS上のnginxコンテナが処理する。

### 9.3.1 ECSクラスタ
ECSクラスタは、Dockerコンテナを実行するホストサーバーを、論理的に束ねるリソースである。リスト9.1のように、クラスタ名を指定するだけである。

リスト9.1: ECSクラスタの定義
```
resource "aws_ecs_cluster" "example" {
  name = "example"
}
```

### 9.3.2 タスク定義
コンテナの実行単位を「**タスク**」と呼ぶ。例えば、Railsアプリケーションの前段にnginxを配置する場合、ひとつのタスクの中でRailsコンテナとnginxコンテナが実行される。<br />
そして、タスクは「**タスク定義**」から生成される。タスク定義では、コンテナ実行時に設定を記述する。オブジェクト指向言語で例えると、タスク定義はクラスで、タスクはインスタンスである。タスク定義はリスト9.2のように実装する。

リスト9.2: タスク定義
```
resource "aws_ecs_task_definition" "example" {
  family = "example"
  cpu = "256"
  memory = "512"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = file("./container_definitions.json")
}
```

#### ファミリー
ファミリーとはタスク定義名のプレフィックスで、familyに設定する。ファミリーにリビジョン番号を付与したものがタスク定義名になる。リスト9.2の場合、最初は「**example:1**」である。リビジョン番号は、タスク定義更新時にインクリメントされる。

#### タスクサイズ
cpuとmemoryで、タスクが使用するリソースのサイズを設定する。cpuはCPUユニットの整数表現(例:1024)か、vCPUの文字列表現(例:1vCPU)で設定する。memoryはMiBの整数表現(例:1024)か、GBの文字列表現(例:1GB)で設定する。<br />
なお、設定できる値の組み合わせは決まっている。例えばcpuに256を指定する場合、memoryで指定できる値は512・1024・2048のいずれかである。

#### ネットワークモード
Fargate起動タイプの場合は、network_modeに「awsvpc」を指定する。

#### 起動タイプ
requires_compatibilitiesに「Fargate」を指定する。

#### コンテナ定義
「container_definitions.json」ファイルにタスクで実行するコンテナを定義する。これはコンテナ定義と呼ばれ、リスト9.3のように実装する。

リスト9.3: コンテナ定義
```
[
    {
        "name": "example",
        "image": "nginx/latest",
        "essential": true,
        "portMappings": [
            {
                "protocol": "tcp",
                "containerPort": 80
            }
        ]
    }
]
```

パラメータの意味は次のとおりである。ほかにも多様なパラメータが設定可能である。
- **name** : コンテナの名前
- **image** : 使用するコンテナイメージ
- **essential** : タスク実行に必須かどうかのフラグ
- **portMappings** : マッピングするコンテナのポート番号

### 9.3.3 ECSサービス
通常、コンテナを起動しても、処理が完了したらすぐに終了する。もちろん、Webサービスでそれは困るため、「**ECSサービス**」を使う。<br />
ECSサービスはリスト9.4のように実装する。ECSサービスは起動するタスクの数を定義でき、指定した数のタスクを維持する。なんらかの理由でタスクが終了してしまった場合、自動的に新しいタスクを起動してくれる優れものである。<br />
また、ECSサービスはALBとの橋渡し役にもなる。インターネットからのリクエストはALBで受け、そのリクエストをコンテナにフォワードする。

リスト9.4: ECSサービスの定義
```
module "loadbalancer" {
    source = "./loadbalancer"
}

# ECSクラスタの定義
resource "aws_ecs_cluster" "example" {
  name = "example"
}

# タスク定義
resource "aws_ecs_task_definition" "example" {
  family = "example"
  cpu = "256"
  memory = "512"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = file("./container_definitions.json")
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
```

#### ECSクラスタとタスク定義