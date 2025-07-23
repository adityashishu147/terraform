resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr

}


resource "aws_iam_role" "ec2_role" {
  name = "iam_aditya_shishu_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}


output "ec2_role_arn" {
  value = aws_iam_role.ec2_role.arn
}

resource "aws_subnet" "sub_1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub_2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}


resource "aws_route_table" "route_table_id" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}


resource "aws_route_table_association" "RT_association_1" {
  subnet_id      = aws_subnet.sub_1.id
  route_table_id = aws_route_table.route_table_id.id

}

resource "aws_route_table_association" "RT_association_2" {
  subnet_id      = aws_subnet.sub_2.id
  route_table_id = aws_route_table.route_table_id.id

}


resource "aws_security_group" "securitygroup1" {
  name        = "web_serve"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "allow_tls"
  }

}

resource "aws_vpc_security_group_ingress_rule" "sgingress1" {
  security_group_id = aws_security_group.securitygroup1.id
  description       = "HTTP from VPC"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}


resource "aws_vpc_security_group_ingress_rule" "sgingress2" {
  security_group_id = aws_security_group.securitygroup1.id
  description       = "SSH from VPC"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "sgingress3" {
  security_group_id = aws_security_group.securitygroup1.id
  description = "Allow all outbound traffic"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "-1"
  to_port     = 0
}

resource "aws_s3_bucket" "s3bucket" {
  bucket = "aditya9893145344"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}



resource "aws_instance" "webserver1" {
  ami                         = "ami-020cba7c55df1f615"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.sub_1.id
  vpc_security_group_ids      = [aws_security_group.securitygroup1.id]
  associate_public_ip_address = true
  user_data                   = file("userdata.sh")
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name 
  tags = {
    Name = "webserver1"
  }
}



resource "aws_instance" "webserver2" {
  ami                         = "ami-020cba7c55df1f615"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.sub_2.id
  vpc_security_group_ids      = [aws_security_group.securitygroup1.id]
  associate_public_ip_address = true
  user_data                   = file("userdata1.sh")
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

}



resource "aws_lb" "myalb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.securitygroup1.id]
  subnets            = [aws_subnet.sub_1.id, aws_subnet.sub_2.id]
  tags = {
    Name = "my-alb"
  }
}


resource "aws_lb_target_group" "mytargetgroup" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}



resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.mytargetgroup.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test2" {
  target_group_arn = aws_lb_target_group.mytargetgroup.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mytargetgroup.arn
  }

}


output "loadbalancer" {
  value       = aws_lb.myalb.dns_name
  description = "The DNS name of the load balancer"

}




