resource "aws_iam_role" "ssm_role" {
  name = "${var.prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.prefix}-instance-profile"
  role = aws_iam_role.ssm_role.name
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    sudo dd if=/dev/zero of=/swapfile bs=128M count=32
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
    yum install docker -y
    systemctl enable docker
    systemctl start docker
    docker network create common
  EOF
}

resource "aws_instance" "main" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  associate_public_ip_address = true

  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.profile.name

  user_data              = local.user_data

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.prefix}-ec2"
  }
}