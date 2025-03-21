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
    cidr_blocks = ["0.0.0.0/0"]  # Replace with your IP for security
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

   # Provisioner to copy the private key to the Bastion Host
  provisioner "file" {
    source      = "/var/lib/jenkins/mykeypairusvir.pem"  # Local private key file
    destination = "/home/ubuntu/mykeypairusvir.pem"
  }

  # Provisioner to set permissions on the copied file
  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ubuntu/mykeypairusvir.pem"
    ]
  }

  # Connection block to define how Terraform connects to the instance
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/var/lib/jenkins/mykeypairusvir.pem")
    host        = self.public_ip
  }

}

# ==============================
# 🛢️ MongoDB EC2 Instance (Private Subnet)
# ==============================

resource "aws_instance" "mongodb-ser" {
  ami           = "ami-0f9de6e2d2f067fca"  # Replace with correct AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private1.id
  security_groups = [aws_security_group.db_sg.id]
  key_name      = "mykeypairusvir"  # Replace with your SSH key

  tags = {
    Name = "MongoDB-Server"
  }
}

# ==============================
# 🔗 VPC Peering
# ==============================

# Fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Create VPC Peering Connection
resource "aws_vpc_peering_connection" "peer_mongodb_default" {
  vpc_id      = aws_vpc.mongodb.id
  peer_vpc_id = data.aws_vpc.default.id
  auto_accept = true

  tags = {
    Name = "mongodb-to-default-peering"
  }
}

# Update Route Table for MongoDB VPC to allow traffic to Default VPC
resource "aws_route" "mongodb_to_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer_mongodb_default.id
}

# Update Route Table for Default VPC to allow traffic to MongoDB VPC
resource "aws_route" "default_to_mongodb" {
  route_table_id         = data.aws_vpc.default.main_route_table_id
  destination_cidr_block = aws_vpc.mongodb.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer_mongodb_default.id
}

# ==============================
# 📤 Output (For Easy Access)
# ==============================

output "vpc_peering_id" {
  value = aws_vpc_peering_connection.peer_mongodb_default.id
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
