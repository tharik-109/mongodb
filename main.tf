provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "mongodb" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Mongodb VPC"
  }
}

# Create Public Subnets
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.mongodb.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.mongodb.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "public-subnet-2"
  }
}

# Create Private Subnets
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.mongodb.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.mongodb.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mongodb.id

  tags = {
    Name = "igw-db"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mongodb.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-rt-db"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway (for Private Subnets)
resource "aws_eip" "nat" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "nat-gw-db"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.mongodb.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt-db"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

# ==============================
# 🔐 Security Groups
# ==============================

# Security Group for Bastion Host (Allows SSH Access)
resource "aws_security_group" "bas_sg" {
  vpc_id = aws_vpc.mongodb.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Replace with your IP for security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bas-sg"
  }
}
# Security Group for MongoDB (Allows only Bastion Host to access)
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.mongodb.id

  # Allow MongoDB Access only from Bastion Host
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    security_groups = [aws_security_group.bas_sg.id]  # Only Bastion can access
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]  # Replace with your IP for security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

# ==============================
# 🖥️ Bastion Host (Jump Server)
# ==============================

resource "aws_instance" "bastion" {
  ami           = "ami-04b4f1a9cf54c11d0"  # Replace with correct AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public1.id
  security_groups = [aws_security_group.bas_sg.id]
  key_name      = "mykeypairusvir"  # Replace with your SSH key

  tags = {
    Name = "Bastion-Host"
  }
}

# ==============================
# 🛢️ MongoDB EC2 Instance (Private Subnet)
# ==============================

resource "aws_instance" "mongodb-ser" {
  ami           = "ami-08b5b3a93ed654d19"  # Replace with correct AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private1.id
  security_groups = [aws_security_group.db_sg.id]
  key_name      = "mykeypairusvir"  # Replace with your SSH key

  tags = {
    Name = "MongoDB-Server"
  }
}

# ==============================
# 📤 Output (For Easy Access)
# ==============================

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "mongodb_private_ip" {
  value = aws_instance.mongodb-ser.private_ip
}
