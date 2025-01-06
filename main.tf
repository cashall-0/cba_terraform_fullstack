provider "aws" {
    region = var.region
}
data "aws_key_pair" "sample_kp" {
  key_name = var.key_name
}
data "aws_ssm_parameter" "instance_ami" {
    #Get the updated available image id from the availability zone specified 
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_vpc" "fullstack_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  instance_tenancy     = "default"
  tags = {
    name = "FullStackVPC"
  }
}

resource "aws_subnet" "fullstack_public_subnet1" {
    vpc_id = aws_vpc.fullstack_vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "eu-west-1a"

    tags = {
        Name = "FullStackPublicSubnet1"
    }
  
}

resource "aws_subnet" "fullstack_public_subnet2" {
    vpc_id = aws_vpc.fullstack_vpc.id
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "eu-west-1b"

    tags = {
        Name = "FullStackPublicSubnet2"
    }
  
}

resource "aws_subnet" "fullstack_private_subnet1" {
    vpc_id = aws_vpc.fullstack_vpc.id
    cidr_block = "10.0.3.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "eu-west-1a"

    tags = {
        Name = "FullStackPrivateSubnet1"
    }
  
}

resource "aws_subnet" "fullstack_private_subnet2" {
    vpc_id = aws_vpc.fullstack_vpc.id
    cidr_block = "10.0.4.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "eu-west-1b"

    tags = {
        Name = "FullStackPrivateSubnet2"
    }
  
}

resource "aws_internet_gateway" "fullstack_igw" {
  vpc_id = aws_vpc.fullstack_vpc.id

  tags = {
    Name = "FullstackIGW"
  }
}

resource "aws_nat_gateway" "fullstack_nat_gw" {
    subnet_id = aws_subnet.fullstack_public_subnet2.id
}


resource "aws_route_table" "fullstack_subnet_rt_public" {
    vpc_id = aws_vpc.fullstack_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.fullstack_igw.id
    }

    tags = {
        "Name" = "FullstackPublicRT"
    }
}

resource "aws_route_table" "fullstack_subnet_rt_private" {
    vpc_id = aws_vpc.fullstack_vpc.id

    route {
        cidr_block = "10.0.0.0/16"
        nat_gateway_id = aws_nat_gateway.fullstack_nat_gw.id
    }

    tags = {
        "Name" = "FullstackPrivateRT"
    }
}
#Associate route tables with respective subnets
resource "aws_route_table_association" "fullstack_subnet_rt_public1" {
    subnet_id = aws_subnet.fullstack_public_subnet1.id
    route_table_id = aws_route_table.fullstack_subnet_rt_public.id
  
}
resource "aws_route_table_association" "fullstack_subnet_rt_public2" {
    subnet_id = aws_subnet.fullstack_public_subnet2.id
    route_table_id = aws_route_table.fullstack_subnet_rt_public.id
  
}
resource "aws_route_table_association" "fullstack_subnet_rt_private1" {
    subnet_id = aws_subnet.fullstack_private_subnet1.id
    route_table_id = aws_route_table.fullstack_subnet_rt_private.id
  
}
resource "aws_route_table_association" "fullstack_subnet_rt_private2" {
    subnet_id = aws_subnet.fullstack_private_subnet2.id
    route_table_id = aws_route_table.fullstack_subnet_rt_private.id
  
}
# Private ALB
resource "aws_lb" "fullstack_elb_internal" {
    name =  "fullstack-internal-elb"
    internal = true
    load_balancer_type = "application"
    subnets = [aws_subnet.fullstack_private_subnet1.id, aws_subnet.fullstack_private_subnet2.id]
    security_groups = [aws_security_group.fullstack_private_sg.id]
    enable_deletion_protection = false
    tags = {
      Name = "FullstackPrivateElb"
    }
}
# Public ALB
resource "aws_lb" "fullstack_elb_external" {
    name =  "fullstack-external-elb"
    internal = false
    load_balancer_type = "application"
    subnets = [aws_subnet.fullstack_public_subnet1.id, aws_subnet.fullstack_public_subnet2.id]
    security_groups = [aws_security_group.fullstack_public_sg.id]
    enable_deletion_protection = false
    tags = {
      Name = "FullstackPublicElb"
    }
}
# Security Group for Public ALB
resource "aws_security_group" "fullstack_public_sg" {
    name        = "fullstack_public_sg"
    vpc_id      = aws_vpc.fullstack_vpc.id
    description = "allow all traffic"
    #inbound
    ingress {
        from_port  = 22
        to_port    = 22
        protocol   = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port  = 80
        to_port    = 80
        protocol   = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #outbound
    egress {
        from_port  = 0
        to_port    = 0
        protocol   = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        name = "FullStackPublicSG"
    }
}
# Security Group for Private
resource "aws_security_group" "fullstack_private_sg" {
    name        = "fullstack_public_sg"
    vpc_id      = aws_vpc.fullstack_vpc.id
    description = "allow all traffic"
    ingress {
        from_port  = 80
        to_port    = 80
        protocol   = "tcp"
        cidr_blocks = [aws_subnet.fullstack_private_subnet1.cidr_block, aws_subnet.fullstack_private_subnet2.cidr_block]
        # Allow traffic only from Public ALB
        security_groups = [ aws_security_group.fullstack_public_sg.id ]
    }
    egress {
        from_port  = 0
        to_port    = 0
        protocol   = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        name = "FullStackPrivateSG"
    }
}

# Target Groups for Public ALB
resource "aws_lb_target_group" "fullstack_public_tg" {
  name     = "fullstack-public-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.fullstack_vpc.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Target Groups for Private ALB
resource "aws_lb_target_group" "fullstack_private_tg" {
  name     = "fullstack-private-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.fullstack_vpc.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener for Public ALB
resource "aws_lb_listener" "public_listener" {
  load_balancer_arn = aws_lb.fullstack_elb_external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fullstack_public_tg.arn
  }
}

# Listener for Private ALB
resource "aws_lb_listener" "private_listener" {
  load_balancer_arn = aws_lb.fullstack_elb_internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fullstack_private_tg.arn
  }
}

# Launch Template
resource "aws_launch_template" "fullstack_launch_template" {
  name_prefix   = "fullstack_app"
  image_id      = data.aws_ssm_parameter.instance_ami.value
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.fullstack_public_sg.id]
  }

  user_data = base64encode("#!/bin/bash echo Hello, World > /var/www/html/index.html systemctl start httpd")
}

# Auto Scaling Group
resource "aws_autoscaling_group" "fullstack_asg" {
  launch_template {
    id      = aws_launch_template.fullstack_launch_template.id
    version = "$Latest"
  }

  #minimum number of EC2 instances that must always be running in the ASG.
  min_size                  = 2
  #maximum number of EC2 instances that the ASG can scale up to
  max_size                  = 5
  desired_capacity          = 2
  #Specifies the subnets where the ASG can launch EC2 instances
  vpc_zone_identifier       = [aws_subnet.fullstack_private_subnet1.id, aws_subnet.fullstack_private_subnet2.id]
  #Associates the ASG with a target group for an Application Load Balance
  target_group_arns         = [aws_lb_target_group.fullstack_public_tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "WebServer"
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "fullstack_scale_out" {
    name = "fullstack_scale_out"
  autoscaling_group_name = aws_autoscaling_group.fullstack_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

resource "aws_autoscaling_policy" "fullstack_scale_in" {
    name = "fullstack_scale_in"
  autoscaling_group_name = aws_autoscaling_group.fullstack_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 20.0
  }
}


# EC2 Instance for Bastion Host
resource "aws_instance" "fullstack_bastion_host" {
  ami           = data.aws_ssm_parameter.instance_ami.value # AMI ID
  instance_type = var.instance_type
  subnet_id     = aws_subnet.fullstack_public_subnet1.id
  security_groups = [aws_security_group.fullstack_public_sg.id]
  associate_public_ip_address = true

  key_name = var.key_name

  tags = {
    Name = "FullstackBastionHost"
  }
}


