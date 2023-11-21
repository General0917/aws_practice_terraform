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
  ami = "ami-014886dca6bd4bce2"
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
  ami = "ami-014886dca6bd4bce2"
  instance_type = local.example_instance_type
}
```

## 3.3 出力値
「***output***」を使うと出力値が定義できる。リスト3.3のように定義すると、<br />
apply時にターミナルで値を確認したり、「3.8 モジュール」から値を取得する際に使える。
- リスト3.3:出力値の定義
```
resource "aws_instance" "example" {
  ami = "ami-014886dca6bd4bce2"
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
