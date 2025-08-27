provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
  profile = "brl" # AWSプロファイル
}

# VPC
resource "aws_vpc" "sample_vpc" {
  cidr_block = "10.0.0.0/24"
}

# サブネット1a (/25)
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.0.0/25"
  availability_zone = "ap-northeast-1a"
}

# サブネット1c (/25)
resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = "ap-northeast-1c"
}

# セキュリティグループ（SSH 用）
resource "aws_security_group" "sample_sg" {
  name        = "sample_sg"
  description = "Allow SSH"
  vpc_id      = aws_vpc.sample_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 インスタンスをサブネットA に配置
resource "aws_instance" "sample_ec2_a" {
  ami           = data.aws_ami.amazon_linux.id 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.sample_sg.id]

  tags = {
    Name = "sample-ec2-a"
  }
}

# EC2 インスタンスをサブネットB に配置
resource "aws_instance" "sample_ec2_c" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_b.id
  vpc_security_group_ids = [aws_security_group.sample_sg.id]

  tags = {
    Name = "sample-ec2-c"
  }
}


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
