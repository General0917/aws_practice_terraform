# 第3章　基本構文
本章ではリソース定義以外の基本的な構文から学ぶ。<br />
本章で学んだ内容に基づいて、第5章から第16章は実装する。<br />

## 3.1 変数

「***variable***」を使うと変数が定義できる。例えば、example_instance_type変数はリスト3.1のように定義する。<br />
なお、リスト3.1ではデフォルト値も設定している。Terraform実行時に変数を上書きしない場合は、このデフォルト値が使われる。
- リスト3.1:変数の定義
```
variable "example_instance_type" {
  default = "t3.micro"
}

resource "aws_instance" "example" {
  ami = "ami-0c3fd0f5d33134a76"
  instance_type = var.example_instance_type
}
```

変数は、実行時に上書き可能で、その方法は複数存在する。例えば、次のように、<br />
コマンド実行時に「-var」オプションで上書きできます。

```
$ terraform plan -var 'example_instance_type=t3.nano'
```

また、環境変数で上書きすることも可能である。環境変数の場合、「TF_VAR_[name]」という名前にすると、<br />
Terraformが自動的に上書きする。

```
$ TF_VAR_example_instance_type=t3.nano terraform plan
```

## 3.2 ローカル変数

「***locals***」を使うとローカル変数が定義できる。リスト3.1をリスト3.2のように変更する。<br />
variableと異なり、localsはコマンド実行時に上書きされない
- リスト3.2:ローカル変数の定義
```
locals {
  example_instance_type = "t3.micro"
}

resource "aws_instance" "example" {
  ami = "ami-0c3fd0f5d33134a76"
  instance_type = local.example_instance_type
}
```

## 3.3 出力値
「***output***」を使うと出力値が定義できる。リスト3.3のように定義すると、<br />
apply時にターミナルで値を確認したり、「3.8 モジュール」から値を取得する際に使える。
- リスト3.3:出力値の定義
```
resource "aws_instance" "example" {
  ami = "ami-0c3fd0f5d33134a76"
  instance_type = local.example_instance_type
}

output "example_instance_id" {
  value = aws_instance.example.id
}
```

applyすると、実行結果の最後に、作成されたインスタンスのIDが出力される。

```
$ terraform apply
Outputs:

example_instance_id = "i-00f05f4f060a127b0"
```

## 3.4 データソース
データソースを使うと外部データを参照することが可能。例えば、<br />
最新のAmazon Linux 2のAMIリスト3.4のように定義すれば参照可能である。<br />
少し複雑であるが、filterなどを使って検索条件を指定し、most_recentで最新のAMIを取得しているだけである。
- リスト3.4:データソースの定義
```
data "aws_ami" "recent_amazon_linux_2" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "example" {
  ami = data.aws_ami.recent_amazon_linux_2.image_id
  instance_type = "t3.micro"
}
```

## 3.5 プロバイダ
TerraformではAWSだけでなくGCPやAzureなどにも対応している。そのAPIの違いを吸収するのがプロバイダの役割である。<br />
実はここまでのコードでは、Terraformが暗黙的にプロバイダを検出していた。<br />
そこで、今度は明示的にAWSプロバイダを定義する。プロバイダの設定は変更可能で、例えばリスト3.5ではリージョンを指定している。
- リスト3.5:プロバイダの定義
```
provider "aws" {
  region = "ap-northeast-1"
}
```
なおプロバイダは、Terraform本体とは分離されている。そのため、`terraform init`コマンドで、<br />
プロバイダのバイナリファイルをダウンロードする必要がある。

## 3.6 参照
第2章のリスト2.3ではApacheをインストールしたEC2インスタンスを作成したが、残念ながらアクセスはできない。<br />
セキュリティグループが必要である。そこでリスト3.6のように実装し、80番ポートを許可する。
- リスト3.6:EC2向けセキュリティグループの定義
```
resource "aws_security_group" "example_ec2" {
  name = "example-ec2"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

次にリスト3.7のように、vpc_security_group_idsからセキュリティグループへの参照を追加し、<br />
EC2インスタンスと関連付ける。なお、vpc_security_group_idsはリスト形式で渡すため、値を[]で囲む
```
resource "aws_instance" "example" {
  ami = "ami-0f7b55661ecbbe44c"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.example_ec2.id]

  user_data = <<EOF
  #!/bin/bash
  yum install -y httpd
  systemctl start httpd.service
EOF
}

output "example_public_dns" {
  value = aws_instance.example.public_dns
}
```

注目すべきは、4行目である。このように「***TYPE.NAME.ATTRIBUTE***」の形式で記載すれば、<br />
他のリソースの値を参照できる。では、applyしてみる。

```
$ terraform apply
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

example_public_dns = "ec2-18-183-120-9.ap-northeast-1.compute.amazonaws.com"
```

出力されたexample_public_dnsにアクセスして、HTMLが返ってくれば成功である
```
$ curl ec2-18-183-120-9.ap-northeast-1.compute.amazonaws.com
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
        <head>
                <title>Test Page for the Apache HTTP Server</title>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
......
```

## 3.7 組み込み関数
Terraformには、文字列操作やコレクション操作など、よくある処理が組み込み関数として提供されている。例えば、外部ファイルを読み込むfile関数を使ってみる。<br />
これまで実装していたmain.tfファイルと同じディレクトリに、「user_data.sh」ファイルを作成し、リスト3.8のようなApacheのインストールスクリプトを実装する。
- リスト3.8:Apacheのインストール
```
#!/bin/bash
yum install -y httpd
systemctl start httpd.service
```

そして、リスト3.9のコードを実装してapplyすると、user_data.shファイルを読み込み、Apacheをインストールする。
```
resource "aws_instance" "example" {
  ami = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"

  user_data = file("./user_data.sh")
}
```

## 3.8 モジュール
他のプログラミング言語同様、Terraformにもモジュール化の仕組みがある。<br />
ここではHTTPサーバーのモジュールを実装する。<br />
モジュールは別ディレクトリを作成する。そして、モジュールを定義するmain.tfファイルを作成する。
```
$ mkdir http_server
$ cd http_server
$ New-Item main.tf
```

すると、次のようなファイルレイアウトになる。
```
|-----http_server
|       main.tf # モジュールを定義するファイル
|-----main.tf # モジュールを利用するファイル
```

### 3.8.1 モジュールの定義
準備ができたので、http_serverディレクトリ配下のmain.tfファイルをエディタで開き、http_serverモジュールを実装する。<br />
リスト3.10のように、EC2インスタンスへApacheをインストールし、80番ポートを許可したセキュリティグループを定義する。http_serverモジュールのインターフェースは次の通りである。

入力パラメータ「***instance_type***」: EC2のインスタンスタイプ

出力パラメータ「***public_dns***」: EC2のパブリックDNS

- リスト3.10:HTTPサーバーモジュールの定義
```
variable "instance_type" {
  
}

resource "aws_instance" "default" {
  ami = "ami-0c3fd0f5d33134a76"
  vpc_security_group_ids = [aws_security_group.default.id]
  instance_type = var.instance_type

  user_data = <<EOF
  #!/bin/bash
  yum install -y httpd
  systemctl start httpd.service
EOF
}

resource "aws_security_group" "default" {
  name = "ec2"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "public_dns" {
    value = aws_instance.default.public_dns
}
```

### 3.8.2 モジュールの利用
次に、モジュールの利用側のディレクトリに移動する。
```
$ cd ../
```

モジュール利用側のmain.tfファイルを開き、リスト3.11のように実装する。利用するモジュールはsourceに指定する。<br />
2行目のように、リスト3.10を実装したディレクトリを指定する。
- リスト3.11:HTTPサーバーモジュールの利用
```
module "web_server" {
  source = "./http_server"
  instance_type = "t3.micro"
}

output "public_dns" {
  value = module.web_server.public_dns
}
```
applyはモジュール利用側のディレクトリで実行する。ただし、モジュールを使用する場合、もうひと手間必要である。<br />
「***terraform get***」コマンドか「***terraform init***」コマンドを実行して、モジュールを事前に取得する必要がある。
```
$ terraform get
- web_server in http_server
```

準備が整ったら、applyし、public_dnsが表示されたら成功である。
```
$ terraform apply
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

public_dns = "ec2-54-250-204-254.ap-northeast-1.compute.amazonaws.com"
```

アクセス可能なサーバーが作成されているので確認する。
```
$ curl ec2-54-250-204-254.ap-northeast-1.compute.amazonaws.com
```

確認出来たら、destoryしてリソースが課金されないようにする。