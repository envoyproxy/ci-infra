resource "aws_default_vpc" "default" {
}

data "aws_subnet_ids" "default" {
  vpc_id = aws_default_vpc.default.id

  filter {
    name = "availability-zone-id"

    values = [
      "use2-az2",
      "use2-az3",
    ]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_${local.asg_name}"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "SSH from World"
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
