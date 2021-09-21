provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

# resource "aws_instance" "devopsng" {
#   ami           = "ami-0c55b159cbfafe1f0"
#   instance_type = "t2.micro"
#   count = 20

#   tags = {
#     Name = "terraform-devopsng"
#   }
# }

resource "aws_instance" "devopsng" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags = {
    Name = "terraform-devopsng"
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-devopsng-instance"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_launch_configuration" "devopsng" {
  image_id        = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_availability_zones" "all" {}

#Deploy a cluster of web servers
resource "aws_autoscaling_group" "devopsng" {
  launch_configuration = aws_launch_configuration.devopsng.id
  availability_zones   = data.aws_availability_zones.all.names
  
  min_size = 6
  max_size = 10

  load_balancers    = [aws_elb.devopsng.name]
  health_check_type = "ELB"
  
  tag {
    key                 = "terraform-devopsng"
    value               = "terraform-asg-devopsng"
    propagate_at_launch = true
  }
}

#loadbalancer for the servers
resource "aws_elb" "devopsng" {
  name               = "terraform-asg-devopsng"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names
  
  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

#security chrck to allow ingress and egress
resource "aws_security_group" "elb" {
  name = "terraform-devopsng-elb"
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "clb_dns_name" {
  value       = aws_elb.devopsng.dns_name
  description = "The domain name of the load balancer"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

#clb_dns_name = "terraform-asg-devopsng-1048332779.us-east-2.elb.amazonaws.com"
#https://blog.gruntwork.io/an-introduction-to-terraform-f17df9c6d180#3fd2