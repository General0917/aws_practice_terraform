# 第7章　ネットワーク
本章ではまず、場ブリックネットワークとプライベートネットワークを作成し、その後マルチAZ化する。<br />
あわせて、AWSのファイアウォールについても学習する

## 7.1 パブリックネットワーク
パブリックネットワークは、インターネットからアクセス可能なネットワークである。<br />
このネットワークに作成されるリソースは、パブリックIPアドレスを持つ。

### 7.1.1 VPC(Virtual Private Cloud)
***VPC(Virtual Private Cloud)***は、他のネットワークから論理的に切り離されている仮想ネットワークである。<br />
EC2などのリソースはVPCに配置する。VPCはリスト7.1のように定義する。

リスト7.1: VPCの定義
```
resource "aws_vpc" "example" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "example"
    }
}
```

#### CIDRブロック
VPCのIPv4アドレスの範囲をCIDR形式(XX.XX.XX.XX/XX)で、cidr_blockに指定する。これはあとから変更できない。<br />
そのため、VPCピアリングなども考慮して、最初にきちんと設計する必要がある。

#### 名前解決
enable_dns_supportをtrueにして、AWSのDNSサーバーによる名前解決を有効にする。<br />
あわせて、VPC内のリソースにパブリックDNSホスト名を自動的に割り当てるため、enable_dns_hostnamesをtrueにする。

#### タグ
AWSでは多くのリソースにタグを指定できる。タグはメタ情報を付与するだけで、リソースの動作には影響しない。リスト7.1ではNameタグを定義している。<br />
VPCのように、いくつかのリソースではNameタグがないと、AWSマネジメントコンソールで見たときに用途がわかりづらくなる。(図7.1)。そのため、タグが設定できるリソースは、Nameタグを入れておく。

図7.1: NameタグがないVPC
![](picture/図7_1.png)

### 7.1.2 パブリックサブネット
VPCをさらに分割し、サブネットを作成する。まずはインターネットからアクセス可能なパブリックサブネットを、リスト7.2のように定義する。

リスト7.2: パブリックサブネットの定義
```
resource "aws_subnet" "public" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
    availability_zone = "ap-northeast-1"
}
```

#### CIDRブロック
サブネットは任意の単位で分割できる。特にこだわりがなければ、VPCでは「/16」単位、サブネットでは「/24」単位にするとわかりやすい。<br />
これは、VPCを利用する際に、接続するIPアドレスの範囲を短くすれば、接続したサブネットを容易に見つけ、接続することが可能であるためである。

#### パブリックIPアドレスの割り当て
map_public_ip_on_launchをtrueに設定すると、そのサブネットで起動したインスタンスにパブリックIPアドレスを自動的に割り当てることが可能である。便利なので、パブリックネットワークではtrueにしておくとよい。

#### アベイラビリティゾーン
availability_zoneに、サブネットを作成するアベイラビリティゾーンを指定する。アベイラビリティゾーンをまたがったサブネットは作成できないので、注意が必要である。

***アベイラビリティゾーンとは何か？*** <br />
第3章ではAWSには複数のリージョンが存在することを学習した。AWSではさらに、リージョン内も複数のロケーションに分割されている。これを「アベイラビリティゾーン(AZ)」と呼ぶ。<br />
そして、複数のアベイラビリティゾーンで構成されたネットワークを「マルチAZ」と呼ぶ。システムをマルチAZ化すると、可用性の向上が可能。

### 7.1.3 インターネットゲートウェイ
VPCは隔離されたネットワークであり、単体ではインターネットと接続できない。そこで、インターネットゲートウェイを作成し、VPCとインターネットの間で通信ができるようにする必要がある。<br />
インターネットゲートウェイはリスト7.3のように、VPCのIDを指定するだけである。

リスト7.3: インターネットゲートウェイの定義
```
resource "aws_internet_gateway" "example" {
    vpc_id = aws_vpc.example.id
}
```

### 7.1.4 ルートテーブル
インターネットゲートウェイだけでは、まだインターネットと通信できない。<br />
ネットワークにデータを流すため、ルーティング情報を管理するルートテーブルが必要である。

#### ルートテーブル
ルートテーブルの定義はリスト7.4のように、VPCのIDを指定するだけである。

リスト7.4: ルートテーブルの定義
```
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.example.id
}
```

ルートテーブルは少し特殊な仕様があるので、注意が必要である。ルートテーブルでは、VPC内の通信を有効にするため、ローカルルートが自動的に作成される。(図7.2)。

図7.2: ルートテーブルをAWSマネジメントコンソールで確認
![](picture/図7_2.png)

VPC内はこのローカルルートによりルーティングされる。ローカルルートは変更や削除ができず、Terraformからも制御できない。<br />
ローカルルートを変更する場合は、ルーティングされているVPCを削除(destroy)し、再applyする必要がある。

#### ルート
ルートは、ルートテーブルの1レコードに該当する。リスト7.5はVPC以外への通信を、インターネットゲートウェイ経由でインターネットへデータを流すために、**デフォルトルート(0.0.0.0/0)** をdestination_cidr_blockに指定する。

リスト7.5: ルートの定義
```
resource "aws_route" "public" {
    route_table_id = aws_route_table.public.id
    gateway_id = aws_internet_gateway.example.id
    destination_cidr_block = "0.0.0.0/0"
}
```

#### ルートテーブルの関連付け
どのルートテーブルを使ってルーティングするかは、サブネット単位で判断する。<br />
そこでルートテーブルとサブネットを、リスト7.6のように関連付ける。

リスト7.6: ルートテーブルの関連付け
```
resource "aws_route_table_association" "public" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}
```

なお、関連付けを忘れた場合、デフォルトルートテーブルが自動的に使われる。<br />
詳細は、「18.1 ネットワーク系デフォルトリソースの使用を避ける」で学習するが、デフォルトルートテーブルの利用はアンチパターンなので、関連付けを忘れないようにする。

## 7.2 プライベートネットワーク
プライベートネットワークは、インターネットから隔離されたネットワークである。<br />
データベースサーバーのような、インターネットからアクセスしないリソースを配置する。<br />
システムをセキュアにするため、パブリックネットワークには必要最小限のリソースのみ配置し、それ以外はプライベートネットワークに置くのが定石である。<br />
要は、社内でのみでしか利用できないシステムをプライベートネットワークのみでしか、接続できないようにするという意味である。

### 7.2.1 プライベートサブネット
インターネットからアクセスできないプライベートサブネットを作成する。

#### サブネット
プライベートサブネットはリスト7.7のように実装する。リスト7.2で作成したサブネットとは異なるCIDRブロックを指定することに注意する。また、パブリックIPアドレスは不要なので、map_public_ip_on_addressはfalseにする。<br />
map_public_ip_on_launchはパブリックアドレスとして、使用するのかのトグルオプションなので、今回はプライベートアドレスとして利用するためfalseに設定する必要がある。

リスト7.7: プライベートサブネットの定義
```
resource "aws_subnet" "private" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.64.0/24"
    availability_zone = "ap-northeast-1a"
    map_public_ip_on_launch = false
}
```

#### ルートテーブルと関連付け
プライベートネットワーク用のルートテーブルをリスト7.8のように実装する。<br />
インターネットゲートウェイに対するルートテーブル定義はもちろん不要である。<br />

リスト7.8: プライベートルートテーブルと関連付けの定義
```
resource "aws_route_table" "private" {
    vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private" {
    subnet_id = aws_subnet.private.id
    route_table_id = aws_route_table.private.id
}
```

### 7.2.2 NATゲートウェイ
**NAT(Network Address Translation)** サーバーを導入すると、プライベートネットワークからインターネットへアクセスできるようになる。自力でも構築は可能だが、AWSではNATのマネージドサービスとして、NATゲートウェイが提供されている。

#### EIP
NATゲートウェイにはEIP(Elastic IP address)が必要である。EIPは静的なパブリックIPアドレスを付与するサービスである。AWSでは、インスタンスを起動するたびに異なるIPアドレスが動的に割り当てられる。<br />
しかし、EIPを使うと、パブリックIPアドレスを固定できる。EIPはリスト7.9のように定義する。

リスト7.9: EIPの定義
```
resource "aws_eip" "nat_gateway" {
    domain = "vpc"
    depends_on = [aws_internet_gateway.example]
}
```

#### NATゲートウェイ
NATゲートウェイは、リスト7.10のように定義する。allocation_idには、リスト7.9で作成したEIPを指定する。また、NATゲートウェイを配置するパブリックサブネットをsubnet_idに指定する。指定するのは、プライベートサブネットではないので間違えないようにする。

リスト7.10: NATゲートウェイの定義
```
resource "aws_nat_gateway" "example" {
    allocation_id = aws_eip.nat_gateway.id
    subnet_id = aws_subnet.public.id
    depends_on = [aws_internet_gateway.example]
}
```

#### ルート
プライベートネットワークからインターネットへ通信するために、ルートを定義する。リスト7.11のように、プライベートサブネットのルートテーブルに追加する。<br />
デフォルトルートをdestination_cidr_blockに指定し、NATゲートウェイにルーティングするよう設定する。

リスト7.11: プライベートルートの定義
```
resource "aws_route" "private" {
    route_table_id = aws_route_table.private.id
    nat_gateway_id = aws_nat_gateway.example.id
    destination_cidr_block = "0.0.0.0/0"
}
```

3行目に注目すると、リスト7.5では「***gateway_id***」を設定していたが、リスト7.11では「***nat_gateway_id***」を設定している。ここは間違えやすいポイントで、applyするまでエラーにならないので、注意が必要である。

### 7.2.3 暗黙的な依存関係
実はEIPやNATゲートウェイは、暗黙的にインターネットゲートウェイに依存している。そこでリスト7.9と7.10では「***depends_on***」を定義した。<br />
depends_onを使って依存を明示すると、インターネットゲートウェイ作成後に、EIPやNATゲートウェイを作成するよう保証できる。この暗黙的な依存関係は、予期せぬ場所でときどき顔を出すが、多くの場合は、Terraformのドキュメントに記載されている。はじめて使用するリソースの場合は、一度ドキュメントを確認して利用してみるのがよい。

- 参考ドキュメント
  - aws_eip
    - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
  - aws_nat_gateway
    - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway

## 7.3 マルチAZ
ネットワークをマルチAZ化するために、複数のアベイラビリティゾーンにサブネットを作成する。<br />
あわせてサブネットに関連するリソースも、それぞれ作成する。

### 7.3.1 パブリックネットワークのマルチAZ化
まずは、パブリックネットワークをマルチAZ化する。

#### サブネット
サブネットを二つ作成するため、リスト7.2をリスト7.12のように変更する。

リスト7.12: パブリックサブネットのマルチAZ化
```
resource "aws_subnet" "public_0" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-northeast-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "public_1" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "ap-northeast-1c"
    map_public_ip_on_launch = true
}
```

4行目と11行目に注目すると、「ap-northeast-1a」と「ap-northeast-1c」という異なるアベイラビリティゾーンを設定している。<br />
これだけで、サブネットがマルチAZ化される。なお各サブネットは、CIDRブロックが重複してはならないので、注意が必要である。<br />
これは、IPアドレスを割り当てる際に、同じCIDRブロックを重複してしまうと、各サブネットで利用可能なパブリックIPアドレスが重複してしまう可能性があるので。

#### ルートテーブルの関連付け
リスト7.6をリスト7.13のように変更し、それぞれのサブネットにルートテーブルを関連付ける。

リスト7.13: パブリックサブネットとルートテーブルの関連付けをマルチAZ化
```
resource "aws_route_table_association" "public_0" {
    subnet_id = aws_subnet.public_0.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
    subnet_id = aws_subnet.public_1.id
    route_table_id = aws_route_table.public.id
}
```

### 7.3.2 プライベートネットワークのマルチAZ化
プライベートネットワークのマルチAZ化のポイントは、NATゲートウェイの冗長化である。そのため、パブリックネットワークと比較すると、変更すべきリソースが多い。

#### サブネット
パブリックネットワークと同様、リスト7.7をリスト7.14のように変更する。

リスト7.14: プライベートサブネットのマルチAZ化
```
resource "aws_subnet" "private_0" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.65.0/24"
    availability_zone = "ap-northeast-1a"
    map_public_ip_on_launch = false
}

resource "aws_subnet" "private_1" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.66.0/24"
    availability_zone = "ap-northeast-1c"
    map_public_ip_on_launch = false
}
```

#### NATゲートウェイ
NATゲートウェイを単体で運用した場合、NATゲートウェイが属するアベイラビリティゾーンに障害が発生すると、もう片方のアベイラビリティゾーンでも通信ができなくなる。<br />
そこで、リスト7.15のように、NATゲートウェイをアベイラビリティゾーンごとに作成する。

リスト7.15: NATゲートウェイのマルチAZ化
```
resource "aws_eip" "nat_gateway_0" {
    domain = "vpc"
    depends_on = [aws_internet_gateway.example]
}

resource "aws_eip" "nat_gateway_1" {
    domain = "vpc"
    depends_on = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_0" {
    allocation_id = aws_eip.nat_gateway_0.id
    subnet_id = aws_subnet.public_0.id
    depends_on = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_1" {
    allocation_id = aws_eip.nat_gateway_1.id
    subnet_id = aws_subnet.public_1.id
    depends_on = [aws_internet_gateway.example]
}
```

#### ルートテーブル
デフォルトルートはひとつのルートテーブルにつき、ひとつしか定義できない。そこでリスト7.16のように、ルートテーブルもアベイラビリティゾーンごとに作成する。

リスト7.16: プライベートサブネットのルートテーブルをマルチAZ化
```
resource "aws_route_table" "private_0" {
    vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_1" {
    vpc_id = aws_vpc.example.id
}

resource "aws_route" "private_0" {
    route_table_id = aws_route_table.private_0.id
    nat_gateway_id = aws_nat_gateway.nat_gateway_0.id
    destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
    route_table_id = aws_route_table.private_1.id
    nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
    destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_0" {
    subnet_id = aws_subnet.private_0.id
    route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
    subnet_id = aws_subnet.private_1.id
    route_table_id = aws_route_table.private_1.id
}
```

## 7.4 ファイアウォール
AWSのファイアウォールには、サブネットレベルで動作する「ネットワークACL」とインスタンスレベルで動作する「セキュリティグループ」がある。<br />
本書では、頻繁に作成することになるセキュリティグループについて学ぶ。

### 7.4.1 セキュリティグループ
セキュリティグループを使うと、OSへ到達する前にネットワークレベルでパケットをフィルタリングできる。<br />
EC2やRDSなど、様々なリソースに設定可能である。

#### セキュリティグループ
リスト3.6では、セキュリティグループルールもaws_security_groupリソースで定義したが、独立したリソースとして定義することもできる。ここでは、別々に実装してみる。まずは、セキュリティグループ本体をリスト7.17のように定義する。

リスト7.17: セキュリティグループの定義
```
resource "aws_security_group" "example" {
    name = "example"
    vpc_id = aws_vpc.example.id
}
```

#### セキュリティグループルール(インバウンド)
次に、セキュリティグループルールである。typeが「ingress」の場合、インバウンドルールになる。リスト7.18では、HTTPで通信できるよう80番ポートを許可する。

リスト7.18: セキュリティグループルール(インバウンド)の定義
```
resource "aws_security_group_rule" "ingress_example" {
    type = "ingress"
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.example.id
}
```

#### セキュリティグループルール(アウトバウンド)
typeが「egress」の場合、アウトバウンドルールになる。リスト7.19では、すべての通信を許可する設定をしている。

リスト7.19: セキュリティグループルール(アウトバウンド)の定義
```
resource "aws_security_group_rule" "egress_example" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.example.id
}
```

#### 7.4.2 セキュリティグループのモジュール化
IAMロール同様、セキュリティグループも頻繁に登場するため、モジュール化する。security_groupディレクトリを作成して、security_groupモジュールを実装する。

#### セキュリティグループのモジュールの定義
security_groupモジュールはリスト7.20のように実装する。入力パラメータは次の4つである。
- **name** : セキュリティグループの名前
- **vpc_id** : VPCのID
- **port** : 通信を許可するポート番号
- **cidr_blocks** : 通信を許可するCIDRブロック

リスト7.20: セキュリティグループモジュールの定義
```

```