# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# 1. Create VPC
resource "aws_vpc" "vpc-demo" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Demo-VPC"
  }
}

# 2. Create Internet Gateway 
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc-demo.id

  tags = {
    Name = "Demo-IG"
  }
}

# 3. Create NAT Gateway
resource "aws_nat_gateway" "demo_nat" {
  subnet_id         = aws_subnet.Private-subnet.id
  connectivity_type = "private"
  depends_on = [ aws_internet_gateway.gw ]
}

# 4. Create Public and Private Subnet 
resource "aws_subnet" "Public-subnet" {
  vpc_id            = aws_vpc.vpc-demo.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public-subnet"
  }
}

resource "aws_subnet" "Private-subnet" {
  vpc_id            = aws_vpc.vpc-demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private-subnet"
  }
}

# 5. Create Public Route Table and associate with Public subnet
resource "aws_route_table" "Public-route-table" {
  vpc_id = aws_vpc.vpc-demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  
  tags = {
    Name = "Public-Route-Table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Public-subnet.id
  route_table_id = aws_route_table.Public-route-table.id
}

# 6. Create Private Route Table and associate with Private Subnet
resource "aws_route_table" "Private-route-table" {
  vpc_id = aws_vpc.vpc-demo.id

  route {
    cidr_block      = "0.0.0.0/0"
    nat_gateway_id  = aws_nat_gateway.demo_nat.id
  }
  
  tags = {
    Name = "Private-Route-Table"
  }
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.Private-subnet.id
  route_table_id = aws_route_table.Private-route-table.id
}

# 7. Create Security Group for Public Web server to allow port 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.vpc-demo.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "allow_Web"
  }
}

# 8. Security Group Private Web server allow for Private Web server to allow port 8080, 80, 443
resource "aws_security_group" "allow_traffic" {
  name        = "Private Web serve security group"
  description = "Allow inbound traffic to Private web server"
  vpc_id      = aws_vpc.vpc-demo.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom tcp"
    from_port   = 8080
    to_port     = 8080
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
    Name = "Private_Web"
  }
}

# 9. Assign Elastic IP to the Public Webserver
resource "aws_eip" "lb" {
  instance = aws_instance.public_web.id
  domain   = "vpc"
}

# 10. Create EC2 Instances
resource "aws_instance" "public_web" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_web.id]
  subnet_id     = aws_subnet.Public-subnet.id

user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y 
              sudo systemctl start apache2
              sudo bash -c 'echo my first webserver > /var/www/html/index.html'
              EOF
       

  tags = {
    Name = "Public-Web"
  }
}

resource "aws_instance" "private_web" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]
  subnet_id     = aws_subnet.Private-subnet.id

 user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y 
              sudo systemctl start apache2
              sudo bash -c 'echo my second webserver > /var/www/html/index.html'
              EOF
       

  tags = {
    Name = "Private-Web"
  }
}