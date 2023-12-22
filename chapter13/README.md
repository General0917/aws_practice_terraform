# 第13章 データストア
本章では、AWSが提供するリレーショナルデータベース「**RDS(Relational Database Service)**」と、インメモリデータストア「**ElastiCache**」について学ぶ。

## 13.1 RDS(Relational Database Service)
RDSはMySQLやPostgreSQL、Oracleなどをサポートする。クラウド向けリレーショナルデータベースのAuroraも人気である。本章ではMySQLを作成する。

### 13.1.1 DBパラメータグループ
MySQLのmy.cnfファイルに定義するようなデータベースの設定は、DBパラメータグループで記述する。リスト13.1のように実装する。

リスト13.1: DBパラメータグループの定義
```
resource "aws_db_parameter_group" "example" {
  name = "example"
  family = "mysql5.7"

  parameter {
    name = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name = "character_set_server"
    value = "utf8mb4"
  }
}
```

#### ファミリー
familyは「mysql5.7」のような、エンジン名とバージョンをあわせた値を設定する。

#### パラメータ
parameterに、設定のパラメータ名と値のペアを指定する。リスト13.1では文字コードを「utf8mb4」に変更している。MySQL自体の設定については、MySQLの[公式ドキュメント](https://dev.mysql.com/doc/)を参照する。

### 13.1.2 DBオプショングループ
DBオプショングループは、データベースエンジンにオプション機能を追加する。例えば、リスト13.2では「MariaDB監査プラグイン」を追加している。MariaDB監査プラグインは、ユーザーのログオンや実行したクエリなどの、アクティビティを記録するためのプラグインである。

リスト13.2: DBオプショングループの定義
```
resource "aws_db_option_group" "example" {
  name = "example"
  engine_name = "mysql"
  major_engine_version = "5.7"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}
```

#### エンジン名とメジャーバージョン
engine_nameには、「mysql」のようなエンジン名を設定する。また、「5.7」のようなメジャーバージョンをmajor_engine_versionに設定する。

#### オプション
optionに追加対象のオプションを指定する。

### 13.1.3 DBサブネットグループ
データベースを稼働させるサブネットを、DBサブネットグループで定義する。<br />
リスト13.3のように、プライベートサブネットを指定する。また、サブネットには異なるアベイラビリティゾーンのものを含める。これは、「13.1.4 DBインスタンス」でマルチAZの設定をする際に必要である。

リスト13.3: DBサブネットグループの定義
```
# 仮想ネットワーク構築
module "vpc" {
  source = "./vpc"
}

resource "aws_db_subnet_group" "example" {
  name = "example"
  subnet_ids = [
    module.vpc.aws_subnet_private_0_id,
    module.vpc.aws_subnet_private_1_id
  ]
}
```

### 13.1.4 DBインスタンス
DBインスタンスをリスト13.4のように実装し、データベースサーバーを作成する。

リスト13.4: DBインスタンスの定義
```
# DBのカスタマーキー作成
module "kms" {
  source = "./kms"
}

resource "aws_db_instance" "example" {
  identifier = "example"
  engine = "mysql"
  engine_version = "5.7.44"
  instance_class = "db.t3.small"
  allocated_storage = 20
  max_allocated_storage = 100
  storage_type = "gp2"
  storage_encrypted = true
  kms_key_id = module.kms.kms_key
  username = "admin"
  password = "kQ3RfPq9"
  multi_az = true
  publicly_accessible = false
  backup_window = "09:10-09:40"
  backup_retention_period = 30
  maintenance_window = "mon:10:10-mon:10:40"
  auto_minor_version_upgrade = false
  deletion_protection = true
  skip_final_snapshot = false
  port = 3306
  apply_immediately = false
  vpc_security_group_ids = [module.mysql_sg.security_group_id]
  parameter_group_name = aws_db_parameter_group.example.name
  option_group_name = aws_db_option_group.example.name
  db_subnet_group_name = aws_db_subnet_group.example.name

  lifecycle {
    ignore_changes = [password]
  }
}
```

#### 識別子
identifierに、データベースのエンドポイントで使う識別子を設定する。

#### エンジン
engineには「mysql」のようなエンジン名を指定する。engine_versionにはパッチバージョンを含めた「5.7.44」のようなバージョンを設定する。

#### インスタンスクラス
instance_classに指定したインスタンスクラスで、CPU・メモリ・ネットワーク帯域のサイズが決定する。<br />
様々な種類があるため、要件に合わせて指定する。

#### ストレージ
allocated_storageでストレージ容量を設定する。storage_typeでは、「汎用SSD」か「プロビジョンドIOPS」を設定する。「gp2」は汎用SSDを意味する。<br />
max_allocated_storageを設定すると、指定した容量まで自動的にスケールする。運用中の予期せぬストレージ枯渇を避けるため設定する。

#### 暗号化
kms_key_idに使用するKMSの鍵を指定すると、ディスク暗号化が有効になる。なお、デフォルトAWS KMS暗号化鍵を使用すると、アカウントをまたいだスナップショットの共有ができなくなる。<br />
レアケースであるが、余計な問題を増やさないためにも、ディスク暗号化には自分で作成した鍵を使用した方がよい。

#### マスターユーザーとマスターパスワード
usernameとpasswordで、マスターユーザーの名前とパスワードをそれぞれ設定する。なお「13.1.5 マスターパスワードの変更」で、設定したパスワードはすぐに変更する。

#### ネットワーク
multi_azをtrueにすると、マルチAZが有効になる。もちろん、リスト13.3で異なるアベイラビリティゾーンのサブネットを指定しておくことが前提である。<br />
また、VPC外からのアクセスを遮断するために、publicly_accessibleをfalseにする。

#### バックアップ
RDSではバックアップが毎日行われる。backup_windowでバックアップのタイミングを設定する。設定は**UTC**で行うことに注意する。なお、メンテナンスウィンドウの前にバックアップウィンドウを設定しておくと安心感が増す。<br />
また、バックアップ期間は最大35日で、backup_retention_periodに設定する。

#### メンテナンス
RDSではメンテナンスが定期的に行われる。maintenance_windowでメンテナンスのタイミングを設定する。バックアップと同様に、**UTC**で設定する。
メンテナンスにはOSやデータベースエンジンの更新が含まれ、メンテナンス自体を無効化することはできない。ただし、auto_minor_version_upgradeをfalseにすると、自動マイナーバージョンアップは無効化できる。

#### 削除保護
deletion_protectionをtrueにして、削除保護を有効にする。<br />
また、インスタンス削除時のスナップショット作成のため、skip_final_snapshotをfalseにする。

#### ポート番号
portでポート番号を設定する。MySQLのデフォルトポートは3306である。

#### 設定変更タイミング
RDSの設定変更のタイミングには、「即時」と「メンテナンスウィンドウ」がある。RDSでは一部の設定変更が伴い、予期せぬダウンタイムが起こりえる。そこで、apply_immediatelyにして、即時反映を避ける。

#### セキュリティグループ
リスト13.5のように、VPC内からの通信のみ許可する。そして、作成したセキュリティグループを、リスト13.4のvpc_security_group_idsに設定する。

リスト13.5: DBインスタンスのセキュリティグループの設定
```
module "mysql_sg" {
  source = "./security_group"
  name = "mysql-sg"
  vpc_id = module.vpc.vpc_id
  port = 3306
  cidr_blocks = [module.vpc.aws_vpc_example_cidr_block]
}
```

### 13.1.5 マスターパスワードの変更
aws_db_instanceリソースのpasswordは必須項目で省略できない。しかも、**パスワードがtfstateファイルに、平文で書き込まれる。**<br />
variableを使って、tfファイルへ平文で書くことを回避しても、tfstateファイルへの書き込みは回避できない。そこで、リスト13.4の34行目のように、ignore_changesで「password」を指定してapplyしたあと、次のようにマスターパスワードを変更する。

```
$ aws rds modify-db-instance --db-instance-identifier 'example' --master-user-password 'Ls3huKbP'
```

#### RDSの削除
リスト13.4で作成したDBインスタンスを削除する場合、destroyコマンドを実行する前に下準備が必要である。<br />
まずは、deletion_protectionをfalseにして、削除保護を無効にする。次にskip_final_snapshotをtrueにして、スナップショットの作成をスキップする。この状態で1度applyする。すると、destroyコマンドでDBインスタンスを削除できるようになる。

## 13.2 ElastiCache