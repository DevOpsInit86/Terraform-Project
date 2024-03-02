# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# 1. Create VPC
resource "aws_vpc" "vpc-demo" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
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

# 3. Create NAT Gateway with Elastic IP
resource "aws_nat_gateway" "demo_nat" {
  allocation_id = aws_eip.demo_eip.id
  subnet_id     = aws_subnet.Public-subnet.id
}

resource "aws_eip" "demo_eip" {
  domain = "vpc" 

  depends_on = [ aws_internet_gateway.gw ]
}

# 4. Create Public and Private Subnet 
resource "aws_subnet" "Public-subnet" {
  vpc_id            = aws_vpc.vpc-demo.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true

  tags = {
    Name = "Public-subnet"
  }
}

resource "aws_subnet" "Private-subnet" {
  vpc_id            = aws_vpc.vpc-demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

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

# 7. Create Security Group for Public Web server to allow port 80, 22 and all traffic
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.vpc-demo.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

# 8. Security Group Private Web server allow for Private Web server to access port  80, 22, and all traffic
resource "aws_security_group" "allow_traffic" {
  name        = "Private Web serve security group"
  description = "Allow inbound traffic to Private web server"
  vpc_id      = aws_vpc.vpc-demo.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
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


# 9. Create Public and private EC2 Instances
resource "aws_instance" "public_web" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  key_name = "my-key-pair"
  vpc_security_group_ids = [aws_security_group.allow_web.id]
  associate_public_ip_address = true
  subnet_id     = aws_subnet.Public-subnet.id

user_data = <<-EOF
              #!/bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo yum install -y git
export META_INST_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
export META_INST_TYPE=`curl http://169.254.169.254/latest/meta-data/instance-type`
export META_INST_AZ=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone`
cd /var/www/html
echo "<!DOCTYPE html>" >> index.html
echo "<html lang="en">" >> index.html
echo "<head>" >> index.html
echo "    <meta charset="UTF-8">" >> index.html
echo "    <meta name="viewport" content="width=device-width, initial-scale=1.0">" >> index.html
echo "    <style>" >> index.html
echo "        @import url('https://fonts.googleapis.com/css?family=Open+Sans&display=swap');" >> index.html
echo "        html {" >> index.html
echo "            position: relative;" >> index.html
echo "            overflow-x: hidden !important;" >> index.html
echo "        }" >> index.html
echo "        * {" >> index.html
echo "            box-sizing: border-box;" >> index.html
echo "        }" >> index.html
echo "        body {" >> index.html
echo "            font-family: 'Open Sans', sans-serif;" >> index.html
echo "            color: #324e63;" >> index.html
echo "        }" >> index.html
echo "        .wrapper {" >> index.html
echo "            width: 100%;" >> index.html
echo "            width: 100%;" >> index.html
echo "            height: auto;" >> index.html
echo "            min-height: 90vh;" >> index.html
echo "            padding: 50px 20px;" >> index.html
echo "            padding-top: 100px;" >> index.html
echo "            display: flex;" >> index.html
echo "        }" >> index.html
echo "        .instance-card {" >> index.html
echo "            width: 100%;" >> index.html
echo "            min-height: 380px;" >> index.html
echo "            margin: auto;" >> index.html
echo "            box-shadow: 12px 12px 2px 1px rgba(13, 28, 39, 0.4);" >> index.html
echo "            background: #fff;" >> index.html
echo "            border-radius: 15px;" >> index.html
echo "            border-width: 1px;" >> index.html
echo "            max-width: 500px;" >> index.html
echo "            position: relative;" >> index.html
echo "            border: thin groove #9c83ff;" >> index.html
echo "        }" >> index.html
echo "        .instance-card__cnt {" >> index.html
echo "            margin-top: 35px;" >> index.html
echo "            text-align: center;" >> index.html
echo "            padding: 0 20px;" >> index.html
echo "            padding-bottom: 40px;" >> index.html
echo "            transition: all .3s;" >> index.html
echo "        }" >> index.html
echo "        .instance-card__name {" >> index.html
echo "            font-weight: 700;" >> index.html
echo "            font-size: 24px;" >> index.html
echo "            color: #6944ff;" >> index.html
echo "            margin-bottom: 15px;" >> index.html
echo "        }" >> index.html
echo "        .instance-card-inf__item {" >> index.html
echo "            padding: 10px 35px;" >> index.html
echo "            min-width: 150px;" >> index.html
echo "        }" >> index.html
echo "        .instance-card-inf__title {" >> index.html
echo "            font-weight: 700;" >> index.html
echo "            font-size: 27px;" >> index.html
echo "            color: #324e63;" >> index.html
echo "        }" >> index.html
echo "        .instance-card-inf__txt {" >> index.html
echo "            font-weight: 500;" >> index.html
echo "            margin-top: 7px;" >> index.html
echo "        }" >> index.html
echo "    </style>" >> index.html
echo "    <title>Amazon EC2 Status</title>" >> index.html
echo "</head>" >> index.html
echo "<body>" >> index.html
echo "    <div class="wrapper">" >> index.html
echo "        <div class="instance-card">" >> index.html
echo "            <div class="instance-card__cnt">" >> index.html
echo "                <div class="instance-card__name">Your EC2 Instance is running!</div>" >> index.html
echo "                <div class="instance-card-inf">" >> index.html
echo "                    <div class="instance-card-inf__item">" >> index.html
echo "                        <div class="instance-card-inf__txt">Instance Id</div>" >> index.html
echo "                        <div class="instance-card-inf__title">" $META_INST_ID "</div>" >> index.html
echo "                    </div>" >> index.html
echo "                    <div class="instance-card-inf__item">" >> index.html
echo "                        <div class="instance-card-inf__txt">Instance Type</div>" >> index.html
echo "                        <div class="instance-card-inf__title">" $META_INST_TYPE "</div>" >> index.html
echo "                    </div>" >> index.html
echo "                    <div class="instance-card-inf__item">" >> index.html
echo "                        <div class="instance-card-inf__txt">Availability zone</div>" >> index.html
echo "                        <div class="instance-card-inf__title">" $META_INST_AZ "</div>" >> index.html
echo "                    </div>" >> index.html
echo "                </div>" >> index.html
echo "            </div>" >> index.html
echo "        </div>" >> index.html
echo "</body>" >> index.html
echo "</html>" >> index.html
sudo service httpd start
              EOF
       

  tags = {
    Name = "Public-Web"
  }
}

resource "aws_instance" "private_web" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  key_name = "my-key-pair"
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]
  subnet_id     = aws_subnet.Private-subnet.id


  tags = {
    Name = "Private-Web"
  }
}