# 第5章　権限管理
AWSでは、あるサービスから別のサービスを操作する際に、権限が必要である。<br />
そこで本章では、AWSのサービスに対する権限付与の方法を学習する。

## 5.1 ポリシー
権限はポリシーで定義する。ポリシーでは「実行可能なアクション」や「操作可能なリソース」を指定でき、柔軟に権限が設定できる。

### 5.1.1 ポリシードキュメント
ポリシーは「ポリシードキュメント」という、リスト5.1のようなJSONで記述する。

リスト5.1: JSON形式のポリシードキュメント
![](picture/json_policy.png)

ポリシードキュメントでは、次のような要素を記述する。
- **Effect**: Allow(許可)またはDeny(拒否)
- **Action**: 何のサービスで、どんな操作が実行できるか
- **Resource**: 操作可能なリソースは何か
リスト5.1は、「リージョン一覧を取得する」という権限を意味する。なお、7行目の「*」は扱いが特殊で「すべて」という意味になる。
リスト5.2のように**aws_iam_policy_document**データソースでもポリシーを記述可能である。<br />
コメントの追加や変数の参照ができて便利である。

リスト5.2: ポリシードキュメントの定義
```
data "aws_iam_policy_document" "allow_describe_regions" {
    statement {
      effect = "Allow"
      actions = ["ec2:DescribeRegions"] # リージョン一覧を取得する
      resources = ["*"]
    }
}
```

### 5.1.2 IAMポリシー
ポリシードキュメントを保持するリソースが「IAMポリシー」である。<br />
リスト5.3のように、ポリシー名とポリシードキュメントを設定する。

リスト5.3: IAMポリシーの定義
```
resource "aws_iam_policy" "example" {
  name = "example"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}
```

## 5.2 ロール
AWSのサービスへ権限を付与するために、「IAMロール」を作成する。

### 5.2.1 信頼ポリシー
IAMロールでは、自身を何のサービスに関連付けるか宣言する必要がある。<br />
その宣言は「信頼ポリシー」と呼ばれ、リスト5.4のように定義する。

リスト5.4: 信頼ポリシーの定義
```
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
```

重要なのは7行目である。リスト5.4では「ec2.amazonaws.com」が指定されているので、<br />
このIAMロールは「EC2にのみ関連付けできる」ということになる。

### 5.2.2 IAMロール
IAMロールはリスト5.5のように定義する。信頼ポリシーとロール名を指定する。

リスト5.5: IAMロールの定義
```
resource "aws_iam_role" "example" {
  name = "example"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
```

### 5.2.3 IAMポリシーのアタッチ
リスト5.6のように、IAMロールにIAMポリシーをアタッチする。<br />
IAMロールとIAMポリシーは、関連付けないと機能しないので注意する。

リスト5.6: IAMポリシーのアタッチ
```
resource "aws_iam_role_policy_attachment" "example" {
  role = aws_iam_role.example.name
  policy_arn = aws_iam_policy.example.arn
}
```

### 5.2.4 IAMロールのモジュール化
IAMロールは本書でも頻繁に登場するため、モジュール化する。<br />
iam_roleディレクトリを作成し、リスト5.7のように実装する。

##### IAMロールモジュールの定義
iam_roleモジュールには3つの入力パラメータを持たせる。
- name: IAMロールとIAMポリシーの名前
- policy: ポリシードキュメント
- identifier: IAMロールを関連付けるAWSサービス識別子

リスト5.7: IAMロールモジュールの定義
```
variable "name" {
  
}

variable "policy" {
  
}

variable "identifier" {
  
}

resource "aws_iam_role" "default" {
    name = var.name
    assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
    statement {
      actions = ["sts.AssumeRole"]

      principals {
        type = "Service"
        identifiers = [var.identifier]
      }
    }
}

resource "aws_iam_policy" "default" {
    name = var.name
    policy =var.policy
}

resource "aws_iam_role_policy_attachment" "default" {
    role = aws_iam_role.default.name
    policy_arn = aws_iam_policy.default.arn
}

output "iam_role_arn" {
    value = aws_iam_role.default.arn
}

output "iam_role_name" {
    value = aws_iam_role.default.name
}
```

##### IAMロールモジュールの利用
iam_roleモジュールはリスト5.8のように利用する。<br />
以降のIAMロールの実装では、このモジュールを使用する。

リスト5.8: IAMロールモジュールの利用
```
module "describe_regions_for_ec2" {
  source = "./iam_role"
  name = "describe-regions-for-ec2"
  identifier = "ec2.amazonaws.com"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}
```