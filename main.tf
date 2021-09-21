provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

resource "aws_instance" "devopsng" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  count = 20

  tags = {
    Name = "terraform-devopsng"
  }
}