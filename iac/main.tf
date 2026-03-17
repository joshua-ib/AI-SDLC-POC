provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "deployer" {
  key_name   = "fastapi-key"
  public_key = var.public_key
}

resource "aws_security_group" "fastapi_sg" {
  name        = "fastapi-sg"
  description = "Allow FastAPI traffic"

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

resource "aws_instance" "fastapi" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 (update per region)
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name

  security_groups = [aws_security_group.fastapi_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git

              cd /home/ec2-user

              # Clone your repo
              git clone https://github.com/${var.github_repo}.git app
              cd app/api/

              python3 -m venv venv
              source venv/bin/activate

              pip install --upgrade pip
              pip install -r requirements.txt

              # Run FastAPI
              nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 &
              EOF

  tags = {
    Name = "fastapi-server"
  }
}