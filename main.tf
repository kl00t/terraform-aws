# Configure the AWS provider
provider "aws" {
  region     = var.region
  access_key = var.access-key
  secret_key = var.secret-key
}

# 1) Create a VPC
resource "aws_vpc" "tf-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production-vpc"
  }
}

# 2) Create Internet Gateway
resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.tf-vpc.id

  tags = {
    Name = "production-internet-gateway"
  }
}

# 3) Create Custom Route Table
resource "aws_route_table" "tf-rt" {
  vpc_id = aws_vpc.tf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.tf-igw.id
  }

  tags = {
    Name = "production-custom-route-table"
  }
}

# 4) Create a subnet
resource "aws_subnet" "tf-subnet-1" {
  vpc_id            = aws_vpc.tf-vpc.id
  cidr_block        = var.subnet-prefix[0].cidr_block
  availability_zone = var.subnet-prefix[0].availability_zone

  tags = {
    Name = var.subnet-prefix[0].name
  }
}

resource "aws_subnet" "tf-subnet-2" {
  vpc_id            = aws_vpc.tf-vpc.id
  cidr_block        = var.subnet-prefix[1].cidr_block
  availability_zone = var.subnet-prefix[1].availability_zone

  tags = {
    Name = var.subnet-prefix[1].name
  }
}

# 5) Associate subnet with route table
resource "aws_route_table_association" "tf-rta" {
  subnet_id      = aws_subnet.tf-subnet-1.id
  route_table_id = aws_route_table.tf-rt.id
}

# 6) Create security group to allow port 22,80,443
resource "aws_security_group" "tf-sg-allow-web" {
  name        = "allow-web-traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.tf-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow all
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow all
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow all
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow Web Traffic"
  }
}

# 7) Create a network interface with an IP in the subnet created in step 4
resource "aws_network_interface" "tf-ni" {
  subnet_id       = aws_subnet.tf-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.tf-sg-allow-web.id]
}

# 8) Assign elastic IP to the network interface in step 2 - requires internet gateway first
resource "aws_eip" "tf-eip" {
  network_interface         = aws_network_interface.tf-ni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.tf-igw]
}

# 9) Create Ubunti server and install/enable apache
resource "aws_instance" "tf-web-server-instance" {
  ami               = "ami-085925f297f89fce1"
  instance_type     = "t2.micro"
  availability_zone = aws_subnet.tf-subnet-1.availability_zone
  key_name          = "terraform-training-access-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.tf-ni.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo basg -c 'echo Your Web Server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "Ubuntu Web Server"
  }
}

output "web-server-public-ip" {
  value = aws_eip.tf-eip.public_ip
}

output "web-server-private-ip" {
  value = aws_instance.tf-web-server-instance.private_ip
}

output "web-server-id" {
  value = aws_instance.tf-web-server-instance.id
}