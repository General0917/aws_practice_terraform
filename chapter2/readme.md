# 基本操作

## 2.1 リソースの作成
事前準備として、まずは適当なディレクトリに「main.tf」というファイルを作成する。
```
$ mkdir example
cd example
touch main.tf
```

### 2.1.1 HCL(HashiCorp Configuration Language)
作成したmain.tfをエディタ(VSCode等)で開き、リスト2.1のように実装する。<br />
このコードではAmazon Linux 2のAMIをベースに、EC2インスタンスを作成する。
- リスト2.1:EC2インスタンスの定義
```
resource "aws_instance" "example" {
  ami = "ami-014886dca6bd4bce2"
  instance_type = "t3.micro"
}
```
Terraformのコードは ***HCL(HashiCorp Configuration Language)*** という言語で実装する。<br />
HCLはTerraformを開発している、HashiCorp社が設計した言語である。<br />
EC2インスタンスのようなリソースは「***resource***」ブロックで定義する
