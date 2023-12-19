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

```