# 仮想ネットワーク構築
module "vpc" {
  source = "./vpc"
}

# DBのカスタマーキー作成
module "kms" {
  source = "./kms"
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
  deletion_protection = false
  skip_final_snapshot = true
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

# DBインスタンスのセキュリティグループの定義
module "mysql_sg" {
  source = "./security_group"
  name = "mysql-sg"
  vpc_id = module.vpc.vpc_id
  port = 3306
  cidr_blocks = [module.vpc.aws_vpc_example_cidr_block]
}

# ElastiCacheパラメータグループの定義
resource "aws_elasticache_parameter_group" "example" {
  name = "example"
  family = "redis5.0"

  parameter {
    name = "cluster-enabled"
    value = "no"
  }
}

# ElastiCacheサブネットグループの定義
resource "aws_elasticache_subnet_group" "example" {
  name = "example"
  subnet_ids = [
    module.vpc.aws_subnet_private_0_id,
    module.vpc.aws_subnet_private_1_id
  ]
}

# ElastiCacheレプリケーショングループの定義
resource "aws_elasticache_replication_group" "example" {
  replication_group_id = "example"
  description = "Cluster Disabled"
  engine = "redis"
  engine_version = "5.0.6"
  num_cache_clusters = 3
  node_type = "cache.t4g.micro"
  snapshot_window = "09:10-10:10"
  snapshot_retention_limit = 7
  maintenance_window = "mon:10:40-mon:11:40"
  automatic_failover_enabled = true
  port = 6379
  apply_immediately = false
  security_group_ids = [module.redis_sg.security_group_id]
  parameter_group_name = aws_elasticache_parameter_group.example.name
  subnet_group_name = aws_elasticache_subnet_group.example.name
}

# ElastiCacheレプリケーショングループのセキュリティグループの定義
module "redis_sg" {
  source = "./security_group"
  name = "redis-sg"
  vpc_id = module.vpc.vpc_id
  port = 6379
  cidr_blocks = [module.vpc.aws_vpc_example_cidr_block]
}