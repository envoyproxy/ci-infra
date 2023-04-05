# The VPN and subnets where Salvo runs its infrastructure and Sandboxes.

resource "aws_vpc" "salvo-vpc" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "salvo-vpc"
  }
}

resource "aws_vpc_dhcp_options" "default-dhcp-options" {
  domain_name         = "us-east-2.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "salvo-vpc-default-dhcp-options" {
  vpc_id          = aws_vpc.salvo-vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.default-dhcp-options.id
}

resource "aws_internet_gateway" "salvo-internet-gateway" {
  vpc_id = aws_vpc.salvo-vpc.id

  tags = {
    Name = "salvo-internet-gateway"
  }
}

resource "aws_route_table" "salvo-infra-route-table" {
  vpc_id = aws_vpc.salvo-vpc.id
}

resource "aws_route_table_association" "salvo-packer-subnet-salvo-infra-route-table" {
  subnet_id      = aws_subnet.salvo-packer-subnet.id
  route_table_id = aws_route_table.salvo-infra-route-table.id
}

resource "aws_subnet" "salvo-packer-subnet" {
  vpc_id     = aws_vpc.salvo-vpc.id
  cidr_block = "192.168.0.0/24"

  tags = {
    Name    = "salvo-packer-subnet"
    Project = "Packer"
  }
}

resource "aws_route_table_association" "salvo-internet-gateway-salvo-infra-route-table" {
  gateway_id     = aws_internet_gateway.salvo-internet-gateway.id
  route_table_id = aws_route_table.salvo-infra-route-table.id
}

resource "aws_default_network_acl" "salvo-vpc-default-acl" {
  default_network_acl_id = aws_vpc.salvo-vpc.default_network_acl_id
  subnet_ids             = [aws_subnet.salvo-packer-subnet.id]

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

resource "aws_default_security_group" "salvo-vpc-default-security-group" {
  vpc_id = aws_vpc.salvo-vpc.id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "salvo-allow-ssh-from-world-security-group" {
  name        = "salvo-allow-ssh-from-world"
  description = "Allow SSH access form the World."
  vpc_id      = aws_vpc.salvo-vpc.id

  ingress {
    description = "Allow SSH from the World."
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
}
