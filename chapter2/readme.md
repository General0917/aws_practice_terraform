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
EC2インスタンスのようなリソースは「***resource***」ブロックで定義する。

### 2.1.2 terraform init
コードを記載したら、作業ディレクトリ(main.tfファイル上に存在するコマンドライン上のディレクトリ内で)「***terraform init***」コマンドを実行し、リソース作成に必要なバイナリファイルをダウンロードする。<br />
「***Terraform has been successfully initialized!***」と表示されていれば、成功である。

```
$ terraform init
Initializing the backend...

Terraform has been successfully initialized!
```

### 2.1.3 terraform plan
次は「***terraform plan***」コマンドで、このコマンドを実行すると「***実行計画***」が出力され、<br />
これから何が起きるのかをTerraformが教えてくれる。<br />
要は、次のterraform apply前にリソースのデプロイ計画をコマンドライン上で出力してくれる。
```
Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.example will be created
  + resource "aws_instance" "example" {
      + ami                                  = "ami-014886dca6bd4bce2"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = (known after apply)
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = (known after apply)
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_lifecycle                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t3.micro"
      ......
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```
「+」マークと共に「aws_instance.example will be created」というメッセージが出力されている。<br />
これは、「***新規にリソース(インフラのサービス)を作成する***」という意味である。

### 2.1.4 terraform apply

