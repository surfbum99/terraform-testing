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

resource "aws_security_group" "openshot_allow_http_ssh" {
  name        = "openshot_allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
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

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.AM-Image.id
  instance_type = "t2.micro"
  count = "3" 
  security_groups = ["${aws_security_group.openshot_allow_http_ssh.name}"]
  key_name = "amkey"

  tags = {
    Name = "Terraform-Instance"
  }

}