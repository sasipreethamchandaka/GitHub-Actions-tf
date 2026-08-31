# ---------------- Key Pair Creation ----------------
resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "sasich_key" {
  key_name   = "sasich"
  public_key = tls_private_key.rsa_key.public_key_openssh

  tags = {
    Name = "sasich"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.rsa_key.private_key_pem
  filename        = "${path.module}/sasich.pem"
  file_permission = "0400"
}

# ---------------- VPC ----------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my_vpc"
  }
}

# ---------------- Subnet ----------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "my_subnet"
  }
}

# ---------------- Internet Gateway ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my_igw"
  }
}

# ---------------- Route Table ----------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

# ---------------- Route Table Association ----------------
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------- Security Group ----------------
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow inbound SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

# ---------------- AMI Data Source ----------------
data "aws_ami" "amzlinux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------- EC2 Instance ----------------
resource "aws_instance" "my_ec2" {
  ami                         = data.aws_ami.amzlinux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  key_name                    = aws_key_pair.sasich_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "my_ec2_instance"
  }
}

# ---------------- Outputs ----------------
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.my_ec2.public_ip
}

output "ssh_command" {
  description = "Command to SSH directly into the instance"
  value       = "ssh -i sasich.pem ec2-user@${aws_instance.my_ec2.public_ip}"
}
