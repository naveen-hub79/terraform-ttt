provider "aws" {}

variable "vpc-cidr" {}
variable "subnet-cidr" {}
variable "env" {}
variable "az" {}
# variable "public_key_location" {}
variable "private_key_location" {}

resource "aws_vpc" "tf_test_vpc" {
    cidr_block = var.vpc-cidr
    tags = {
        Name = "${var.env}-vpc"
    }
}

resource "aws_subnet" "tf-sn-1" {
    vpc_id = aws_vpc.tf_test_vpc.id
    cidr_block = var.subnet-cidr
    availability_zone = var.az
    tags = {
        Name: "${var.env}-subnet-1"
    }
}

resource "aws_internet_gateway" "tf_test_igw" {
    vpc_id = aws_vpc.tf_test_vpc.id
    tags = {
        Name = "${var.env}-igw"
    }
}

resource "aws_route_table" "tf_test_rtb" {
    vpc_id = aws_vpc.tf_test_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.tf_test_igw.id
    }
    tags = {
        Name = "${var.env}-rtb"
    }
}

resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.tf-sn-1.id
    route_table_id = aws_route_table.tf_test_rtb.id
}

resource "aws_security_group" "tf_test_sg" {
    name = "tf_test_sg"
    vpc_id = aws_vpc.tf_test_vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env}-sg"
    }
}

data "aws_ami" "amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter {
        name = "virtualization-type"
        values= ["hvm"]
    }
}

output "ami_id" {
    value = data.aws_ami.amazon-linux-image.id
}

resource "aws_instance" "tf-app-server" {
    ami = data.aws_ami.amazon-linux-image.id
    instance_type = "t2.micro"
    key_name = "tf-key"
    associate_public_ip_address = true
    subnet_id = aws_subnet.tf-sn-1.id
    vpc_security_group_ids = [aws_security_group.tf_test_sg.id]
    availability_zone = var.az

    tags = {
        Name = "${var.env}-server"
    }

    connection {
        type = "ssh"
        host = self.public_ip
        user = "ec2-user"
        private_key = file(var.private_key_location)
    }

    provisioner "file" {
        source = "ec2-script.sh"
        destination = "/home/ec2-user/ec2-script.sh"
    }

    provisioner "remote-exec" {
        script = file("ec2-script.sh")
    }

    # provisioner "remote-exec" {
    #     inline = [
    #         "export ENV-dev",
    #         "mkdir tfdir"
    #     ]
    
    # }

}
