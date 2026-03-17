provider "aws" {
  region = var.aws_region
}

# ----------------------
# VPC
# ----------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "fastapi-vpc"
  }
}

# ----------------------
# Subnets (2)
# ----------------------
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "fastapi-subnet-a"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "fastapi-subnet-b"
  }
}

# ----------------------
# Internet Gateway
# ----------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "fastapi-igw"
  }
}

# ----------------------
# Route Table
# ----------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "fastapi-public-rt"
  }
}

# Associate route table with both subnets
resource "aws_route_table_association" "subnet_a_assoc" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet_b_assoc" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# ----------------------
# Security Group
# ----------------------
resource "aws_security_group" "fastapi_sg" {
  name   = "fastapi-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
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


# ----------------------
# EC2 Instance (in subnet A)
# ----------------------
resource "aws_instance" "fastapi" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.fastapi_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git

              cd /home/ec2-user

              git clone https://github.com/${var.github_repo}.git app
              cd app/api/

              python3 -m venv venv
              source venv/bin/activate

              pip install --upgrade pip
              pip install -r requirements.txt

              nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 &
              EOF

  tags = {
    Name = "fastapi-server"
  }
}
