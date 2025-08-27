# AWS VPCネットワークコンポーネント詳細

## 目的
学習効果
このハンズオンで以下の実践的スキルを身に着けたい

ネットワーク設計: CIDR計算とサブネット分割（/24でVPCをきって/25で2分割）
Infrastructure as Code: 宣言的な設定管理
AWS基礎サービス: VPC、EC2、セキュリティグループ
運用ワークフロー: 計画→実行→削除の流れ
エラー対応: 実際の問題解決経験

## 1. VPC (Virtual Private Cloud)
- **役割**: AWS内の仮想ネットワーク空間を作成
- **CIDR**: `10.0.0.0/24` (256個のIPアドレス)
- **機能**: 
  - ネットワークを論理的に分離
  - セキュリティグループやNACLでアクセス制御
  - DNS解決の設定

```hcl
resource "aws_vpc" "sample_vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true  # DNSホスト名を有効化
  enable_dns_support   = true  # DNS解決を有効化
}
```

## 2. サブネット (Subnet)
- **役割**: VPC内をさらに細かく分割したネットワーク範囲
- **分割**: `/24` → `/25` × 2
  - サブネットA: `10.0.0.0/25` (128IP)
  - サブネットB: `10.0.0.128/25` (128IP)
- **AZ分散**: 可用性を高めるため異なるAZに配置

```
VPC: 10.0.0.0/24
├── サブネットA (AZ: ap-northeast-1a): 10.0.0.0/25   [IP: 0-127]
└── サブネットB (AZ: ap-northeast-1c): 10.0.0.128/25 [IP: 128-255]
```

## 3. インターネットゲートウェイ (IGW)
- **役割**: VPCとインターネット間の通信ゲートウェイ
- **機能**:
  - パブリックIPアドレスの変換
  - インターネットへのルーティング
  - 双方向通信を可能にする

```hcl
resource "aws_internet_gateway" "sample_igw" {
  vpc_id = aws_vpc.sample_vpc.id
  # VPCにアタッチされる
}
```

## 4. ルートテーブル (Route Table)
- **役割**: ネットワークトラフィックの転送先を決定
- **デフォルトルート**: `0.0.0.0/0` → IGW
- **ローカルルート**: `10.0.0.0/24` → local (自動作成)

```hcl
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.sample_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"           # すべてのトラフィック
    gateway_id = aws_internet_gateway.sample_igw.id  # IGWに転送
  }
}
```

### ルートテーブルの内容
| 宛先 | ターゲット | 説明 |
|------|------------|------|
| `10.0.0.0/24` | local | VPC内通信（自動作成） |
| `0.0.0.0/0` | igw-xxxxx | インターネット通信 |

## 5. ルートテーブル関連付け
- **役割**: サブネットにどのルートテーブルを適用するかを指定
- **必須**: サブネットは必ずルートテーブルと関連付けが必要

```hcl
resource "aws_route_table_association" "public_rta_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}
```

## 6. セキュリティグループ (Security Group)
- **役割**: EC2インスタンス単位のファイアウォール
- **ステートフル**: 送信許可したトラフィックの応答は自動許可
- **デフォルト**: すべてのインバウンド拒否、アウトバウンド許可

```hcl
resource "aws_security_group" "sample_sg" {
  name_prefix = "sample_sg"
  vpc_id      = aws_vpc.sample_vpc.id
  
  # インバウンドルール
  ingress {
    from_port   = 22        # SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 全世界からアクセス可能
  }
  
  # アウトバウンドルール
  egress {
    from_port   = 0         # 全ポート
    to_port     = 0
    protocol    = "-1"      # 全プロトコル
    cidr_blocks = ["0.0.0.0/0"]  # 全世界へアクセス可能
  }
}
```

## 7. EC2インスタンス
- **配置**: 特定のサブネット内に作成
- **セキュリティ**: セキュリティグループでアクセス制御
- **パブリックIP**: `map_public_ip_on_launch = true`で自動割り当て

```hcl
resource "aws_instance" "sample_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id             = aws_subnet.public_subnet_a.id      # サブネット指定
  vpc_security_group_ids = [aws_security_group.sample_sg.id] # SG指定
}
```

## 依存関係の理由

### なぜこの順序なのか？
1. **VPC** → すべてのネットワークリソースの基盤
2. **IGW** → インターネット接続に必要
3. **サブネット** → VPCの一部として存在
4. **ルートテーブル** → トラフィック転送ルール定義
5. **SG** → EC2の通信制御ルール
6. **EC2** → 上記すべてが整ってから作成可能

### 削除時は逆順
- EC2が他リソースを使用しているため最初に削除
- 依存されているリソース（VPC）は最後に削除



## エラー発生その１
AMI ID が古い/存在しない:

```hcl
Error: InvalidAMIID.NotFound: The image id '[ami-0dfba1652dfe1c687]' does does not exist
```

- main.tfファイルの修正

1. AMIのデータソース追加

```hcl
# 最新のAmazon Linux 2 AMIを動的に取得
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```
2. EC2リソース修正

```hcl
# EC2 インスタンスをサブネットA に配置
resource "aws_instance" "sample_ec2" {
  ami           = data.aws_ami.amazon_linux.id  # ←ここを修正
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.sample_sg.name]
  tags = {
    Name = "sample-ec2"
  }
}
```

## エラー発生その2
VPC内のEC2インスタンスでは、security_groups（グループ名）ではなくvpc_security_group_ids（グループID）を使う必要あり

```hcl
InvalidParameterCombination: The parameter groupName cannot be used with the parameter subnet
```

- main.tfファイルの修正

```hcl
# EC2 インスタンスをサブネットA に配置
resource "aws_instance" "sample_ec2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.sample_sg.id]  # ←ここを修正
  tags = {
    Name = "sample-ec2"
  }
}
```

- 作成されたリソース確認
同じサブネットにEC2をたててしまった

```hcl
terraform show
# data.aws_ami.amazon_linux:
data "aws_ami" "amazon_linux" {
    architecture          = "x86_64"
    arn                   = "arn:aws:ec2:ap-northeast-1::image/ami-09ed31f8f34719e20"
    block_device_mappings = [
        {
            device_name  = "/dev/xvda"
            ebs          = {
                "delete_on_termination"      = "true"
                "encrypted"                  = "false"
                "iops"                       = "0"
                "snapshot_id"                = "snap-0ce38b07295c18567"
                "throughput"                 = "0"
                "volume_initialization_rate" = "0"
                "volume_size"                = "8"
                "volume_type"                = "gp2"
            }
            no_device    = ""
            virtual_name = ""
        },
    ]
    creation_date         = "2025-08-16T04:54:04.000Z"
    deprecation_time      = "2025-11-14T04:54:00.000Z"
    description           = "Amazon Linux 2 AMI 2.0.20250818.2 x86_64 HVM gp2"
    ena_support           = true
    hypervisor            = "xen"
    id                    = "ami-09ed31f8f34719e20"
    image_id              = "ami-09ed31f8f34719e20"
    image_location        = "amazon/amzn2-ami-hvm-2.0.20250818.2-x86_64-gp2"
    image_owner_alias     = "amazon"
    image_type            = "machine"
    include_deprecated    = false
    most_recent           = true
    name                  = "amzn2-ami-hvm-2.0.20250818.2-x86_64-gp2"
    owner_id              = "137112412989"
    owners                = [
        "amazon",
    ]
    platform_details      = "Linux/UNIX"
    product_codes         = []
    public                = true
    region                = "ap-northeast-1"
    root_device_name      = "/dev/xvda"
    root_device_type      = "ebs"
    root_snapshot_id      = "snap-0ce38b07295c18567"
    sriov_net_support     = "simple"
    state                 = "available"
    state_reason          = {
        "code"    = "UNSET"
        "message" = "UNSET"
    }
    tags                  = {}
    usage_operation       = "RunInstances"
    virtualization_type   = "hvm"

    filter {
        name   = "name"
        values = [
            "amzn2-ami-hvm-*-x86_64-gp2",
        ]
    }
    filter {
        name   = "virtualization-type"
        values = [
            "hvm",
        ]
    }
}

# aws_instance.sample_ec2_a:
resource "aws_instance" "sample_ec2_a" {
    ami                                  = "ami-09ed31f8f34719e20"
    arn                                  = "arn:aws:ec2:ap-northeast-1:026513275849:instance/i-01630b510631e1a1f"
    associate_public_ip_address          = false
    availability_zone                    = "ap-northeast-1a"
    disable_api_stop                     = false
    disable_api_termination              = false
    ebs_optimized                        = false
    force_destroy                        = false
    get_password_data                    = false
    hibernation                          = false
    id                                   = "i-01630b510631e1a1f"
    instance_initiated_shutdown_behavior = "stop"
    instance_state                       = "running"
    instance_type                        = "t2.micro"
    ipv6_address_count                   = 0
    ipv6_addresses                       = []
    monitoring                           = false
    placement_partition_number           = 0
    primary_network_interface_id         = "eni-02e3de8c5641a412f"
    private_dns                          = "ip-10-0-0-5.ap-northeast-1.compute.internal"
    private_ip                           = "10.0.0.5"
    region                               = "ap-northeast-1"
    secondary_private_ips                = []
    security_groups                      = []
    source_dest_check                    = true
    subnet_id                            = "subnet-0e3871e3cb8a9a708"
    tags                                 = {
        "Name" = "sample-ec2-a"
    }
    tags_all                             = {
        "Name" = "sample-ec2-a"
    }
    tenancy                              = "default"
    user_data_replace_on_change          = false
    vpc_security_group_ids               = [
        "sg-01c968bd01ac31e6c",
    ]

    capacity_reservation_specification {
        capacity_reservation_preference = "open"
    }

    cpu_options {
        core_count       = 1
        threads_per_core = 1
    }

    credit_specification {
        cpu_credits = "standard"
    }

    enclave_options {
        enabled = false
    }

    maintenance_options {
        auto_recovery = "default"
    }

    metadata_options {
        http_endpoint               = "enabled"
        http_protocol_ipv6          = "disabled"
        http_put_response_hop_limit = 1
        http_tokens                 = "optional"
        instance_metadata_tags      = "disabled"
    }

    primary_network_interface {
        delete_on_termination = true
        network_interface_id  = "eni-02e3de8c5641a412f"
    }

    private_dns_name_options {
        enable_resource_name_dns_a_record    = false
        enable_resource_name_dns_aaaa_record = false
        hostname_type                        = "ip-name"
    }

    root_block_device {
        delete_on_termination = true
        device_name           = "/dev/xvda"
        encrypted             = false
        iops                  = 100
        tags                  = {}
        tags_all              = {}
        throughput            = 0
        volume_id             = "vol-04c44de3d2ab61a61"
        volume_size           = 8
        volume_type           = "gp2"
    }
}

# aws_instance.sample_ec2_c:
resource "aws_instance" "sample_ec2_c" {
    ami                                  = "ami-09ed31f8f34719e20"
    arn                                  = "arn:aws:ec2:ap-northeast-1:026513275849:instance/i-066f64cde5f0f7b85"
    associate_public_ip_address          = false
    availability_zone                    = "ap-northeast-1a"
    disable_api_stop                     = false
    disable_api_termination              = false
    ebs_optimized                        = false
    force_destroy                        = false
    get_password_data                    = false
    hibernation                          = false
    id                                   = "i-066f64cde5f0f7b85"
    instance_initiated_shutdown_behavior = "stop"
    instance_state                       = "running"
    instance_type                        = "t2.micro"
    ipv6_address_count                   = 0
    ipv6_addresses                       = []
    monitoring                           = false
    placement_partition_number           = 0
    primary_network_interface_id         = "eni-01152b790db46ed03"
    private_dns                          = "ip-10-0-0-38.ap-northeast-1.compute.internal"
    private_ip                           = "10.0.0.38"
    region                               = "ap-northeast-1"
    secondary_private_ips                = []
    security_groups                      = []
    source_dest_check                    = true
    subnet_id                            = "subnet-0e3871e3cb8a9a708"
    tags                                 = {
        "Name" = "sample-ec2-c"
    }
    tags_all                             = {
        "Name" = "sample-ec2-c"
    }
    tenancy                              = "default"
    user_data_replace_on_change          = false
    vpc_security_group_ids               = [
        "sg-01c968bd01ac31e6c",
    ]

    capacity_reservation_specification {
        capacity_reservation_preference = "open"
    }

    cpu_options {
        core_count       = 1
        threads_per_core = 1
    }

    credit_specification {
        cpu_credits = "standard"
    }

    enclave_options {
        enabled = false
    }

    maintenance_options {
        auto_recovery = "default"
    }

    metadata_options {
        http_endpoint               = "enabled"
        http_protocol_ipv6          = "disabled"
        http_put_response_hop_limit = 1
        http_tokens                 = "optional"
        instance_metadata_tags      = "disabled"
    }

    primary_network_interface {
        delete_on_termination = true
        network_interface_id  = "eni-01152b790db46ed03"
    }

    private_dns_name_options {
        enable_resource_name_dns_a_record    = false
        enable_resource_name_dns_aaaa_record = false
        hostname_type                        = "ip-name"
    }

    root_block_device {
        delete_on_termination = true
        device_name           = "/dev/xvda"
        encrypted             = false
        iops                  = 100
        tags                  = {}
        tags_all              = {}
        throughput            = 0
        volume_id             = "vol-0abf329ea913b2ed8"
        volume_size           = 8
        volume_type           = "gp2"
    }
}

# aws_security_group.sample_sg:
resource "aws_security_group" "sample_sg" {
    arn                    = "arn:aws:ec2:ap-northeast-1:026513275849:security-group/sg-01c968bd01ac31e6c"
    description            = "Allow SSH"
    egress                 = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    id                     = "sg-01c968bd01ac31e6c"
    ingress                = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 22
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 22
        },
    ]
    name                   = "sample_sg"
    owner_id               = "026513275849"
    region                 = "ap-northeast-1"
    revoke_rules_on_delete = false
    tags                   = {}
    tags_all               = {}
    vpc_id                 = "vpc-0915d8517075f1851"
}

# aws_subnet.subnet_a:
resource "aws_subnet" "subnet_a" {
    arn                                            = "arn:aws:ec2:ap-northeast-1:026513275849:subnet/subnet-0e3871e3cb8a9a708"
    assign_ipv6_address_on_creation                = false
    availability_zone                              = "ap-northeast-1a"
    availability_zone_id                           = "apne1-az4"
    cidr_block                                     = "10.0.0.0/25"
    enable_dns64                                   = false
    enable_lni_at_device_index                     = 0
    enable_resource_name_dns_a_record_on_launch    = false
    enable_resource_name_dns_aaaa_record_on_launch = false
    id                                             = "subnet-0e3871e3cb8a9a708"
    ipv6_native                                    = false
    map_customer_owned_ip_on_launch                = false
    map_public_ip_on_launch                        = false
    owner_id                                       = "026513275849"
    private_dns_hostname_type_on_launch            = "ip-name"
    region                                         = "ap-northeast-1"
    tags                                           = {}
    tags_all                                       = {}
    vpc_id                                         = "vpc-0915d8517075f1851"
}

# aws_subnet.subnet_b:
resource "aws_subnet" "subnet_b" {
    arn                                            = "arn:aws:ec2:ap-northeast-1:026513275849:subnet/subnet-00ab8da221c240127"
    assign_ipv6_address_on_creation                = false
    availability_zone                              = "ap-northeast-1c"
    availability_zone_id                           = "apne1-az1"
    cidr_block                                     = "10.0.0.128/25"
    enable_dns64                                   = false
    enable_lni_at_device_index                     = 0
    enable_resource_name_dns_a_record_on_launch    = false
    enable_resource_name_dns_aaaa_record_on_launch = false
    id                                             = "subnet-00ab8da221c240127"
    ipv6_native                                    = false
    map_customer_owned_ip_on_launch                = false
    map_public_ip_on_launch                        = false
    owner_id                                       = "026513275849"
    private_dns_hostname_type_on_launch            = "ip-name"
    region                                         = "ap-northeast-1"
    tags                                           = {}
    tags_all                                       = {}
    vpc_id                                         = "vpc-0915d8517075f1851"
}

# aws_vpc.sample_vpc:
resource "aws_vpc" "sample_vpc" {
    arn                                  = "arn:aws:ec2:ap-northeast-1:026513275849:vpc/vpc-0915d8517075f1851"
    assign_generated_ipv6_cidr_block     = false
    cidr_block                           = "10.0.0.0/24"
    default_network_acl_id               = "acl-07949b2846d32ecd1"
    default_route_table_id               = "rtb-0f11366ccbd7874b7"
    default_security_group_id            = "sg-0962ec586c461c39e"
    dhcp_options_id                      = "dopt-0c898372d2f3c58e5"
    enable_dns_hostnames                 = false
    enable_dns_support                   = true
    enable_network_address_usage_metrics = false
    id                                   = "vpc-0915d8517075f1851"
    instance_tenancy                     = "default"
    ipv6_netmask_length                  = 0
    main_route_table_id                  = "rtb-0f11366ccbd7874b7"
    owner_id                             = "026513275849"
    region                               = "ap-northeast-1"
    tags                                 = {}
    tags_all                             = {}
}
```
