data "aws_ami" "ecs_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized*"]
  }
}

data "aws_ami" "aws_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags {
    Name = "${var.name}"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "${var.name} Public Subnet"
  }
}

resource "aws_subnet" "public_second_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "${var.name} Public Second Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "${var.name} Private Subnet"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.name} Internet Gateway"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true

  tags {
    Name = "${var.name} NAT Gateway EIP"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"

  tags {
    Name = "${var.name} NAT"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "${aws_internet_gateway.internet_gateway.id}"
  }

  tags {
    Name = "${var.name} Public Route Table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat_gateway.id}"
  }

  tags {
    Name = "${var.name} Private Route Table"
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_route_table_association" "second_route_table_association" {
  subnet_id      = "${aws_subnet.public_second_subnet.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.private_route_table.id}"
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.aws_name}"
}
