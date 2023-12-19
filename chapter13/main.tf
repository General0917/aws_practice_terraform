# 仮想ネットワーク構築
module "vpc" {
  source = "./vpc"
}

# DBパラメータグループの定義
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

# DBオプショングループの定義
resource "aws_db_option_group" "example" {
  name = "example"
  engine_name = "mysql"
  major_engine_version = "5.7"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}

# DBサブネットグループの定義
resource "aws_db_subnet_group" "example" {
  name = "example"
  subnet_ids = [
    module.vpc.aws_subnet_private_0_id,
    module.vpc.aws_subnet_private_1_id
  ]
}

# DBインスタンスの定義