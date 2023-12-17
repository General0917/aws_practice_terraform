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
