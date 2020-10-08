# Configure the AWS Provider
provider "aws" {
  version = "~> 3.0"
  region  = "eu-west-2"
}

data "aws_ami" "AM-Image" {
  most_recent      = true
  owners = ["356439070975"]


  filter {
    name   = "name"
    values = ["AM-Image"]
  }
}

# Declaring AWS data (read only fetches)

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Declare Input variables

variable "server_port_http" {
  description = "The is the HTTP Server port of the WebServers"
  type = number
  default = 80
}

variable "server_port_ssh" {
  description = "The is the SSH Server port connecting to instances"
  type = number
  default = 22
}

# Output Variables

/* output "public_ip" {
  value = aws_instance.web[*].public_ip
  description = "The Public IP address of the web server"
}
*/

output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}



# Declaring AWS  resources

resource "aws_security_group" "openshot_allow_http_ssh" {
  name        = "openshot_allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    description = "HTTP from VPC"
    from_port   = var.server_port_http
    to_port     = var.server_port_http
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = var.server_port_ssh
    to_port     = var.server_port_ssh
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_launch_configuration" "web" {
  image_id           = data.aws_ami.AM-Image.id
  instance_type = "t2.micro" 
  security_groups = [aws_security_group.openshot_allow_http_ssh.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              cd /var/www/html
              echo "Hello World from Terraform" > index.html
              EOF

  key_name = "amkey"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "web" {
  launch_configuration = aws_launch_configuration.web.name
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_lb" "example" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default.ids
  security_groups = [aws_security_group.openshot_allow_http_ssh.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port = var.server_port_http
  protocol = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = "404"
    }
  }
}

resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port = var.server_port_http
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold =2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
       values = ["*"]
    }
   
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn

  }
}


