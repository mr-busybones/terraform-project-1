provider "aws"{
region= "ap-south-1"
profile= "Chaman"
}

//GENERATING THE KEY USING THE RSA ALGORITHM


resource "tls_private_key" "mykey" {
	algorithm = "RSA"
}
output "key_ssh" {
	value = tls_private_key.mykey.public_key_openssh
}
output "key_pem" {
	value = tls_private_key.mykey.public_key_pem
}
resource "aws_key_pair" "opensshkey"{
	key_name = "mykey"
	public_key = tls_private_key.mykey.public_key_openssh
}


//CREATING A SECURITY GROUP

resource "aws_security_group" "imsecure" {
	name        = "imsecure"
	description = "Allow SSH and HTTP requests"

	ingress= [{
	description = "SSH login"
	from_port   = 22
	to_port     = 22
	protocol    = "tcp"
	ipv6_cidr_blocks = null
    prefix_list_ids = null
    security_groups = null
    self = null
    cidr_blocks = ["0.0.0.0/0"]
	},
	{
	description = "HTTP request from client"
	from_port   = 80
	to_port     = 80
	protocol    = "tcp"
	ipv6_cidr_blocks = null
    prefix_list_ids = null
    security_groups = null
    self = null
    cidr_blocks = ["0.0.0.0/0"]
	}]

	egress {
	from_port   = 0
	to_port     = 0
	protocol    = "-1"
	cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
	Name = "imsecure"
	}
}


//LAUNCHING EC2 INSTANCE 


resource "aws_instance" "TerraOS"{
	ami= "ami-0447a12f28fddb066"
	instance_type= "t2.micro"
	key_name = "mykey"
	security_groups=["imsecure"]

	//ESTABLISHING CONNECTION TO THE REMOTE SYSTEM


	connection {
		type     = "ssh"
		user     = "ec2-user"
		private_key = tls_private_key.mykey.private_key_pem
		host     = aws_instance.TerraOS.public_ip
	}


	//COMMANDS TO BE RUN ON REMOTE OS

	provisioner "remote-exec" {
		inline = [
		"sudo yum install httpd  git -y",
		"sudo systemctl restart httpd",
		"sudo systemctl enable httpd",
		]
	}
	tags={
	Name=" TerraOS"
	}
}


//CREATING AN EBS VOLUME

resource "aws_ebs_volume" "persistentMe" {
  availability_zone = aws_instance.TerraOS.availability_zone
  size              = 1

  tags = {
    Name = "persistentMe"
  }
}

// ATTACH EBS VOLUME TO TERRAOS

resource "aws_volume_attachment" "attach" {
depends_on=[
	aws_instance.TerraOS,
	aws_ebs_volume.persistentMe,
	]
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.persistentMe.id}"
  instance_id = "${aws_instance.TerraOS.id}"
  force_detach   = true
  


connection {
		type     = "ssh"
		user     = "ec2-user"
		private_key = tls_private_key.mykey.private_key_pem
		host     = aws_instance.TerraOS.public_ip
	}

  provisioner "remote-exec" {
		inline = [
		"sudo mkfs.ext4 /dev/xvdh",
		"sudo mount /dev/xvdh /var/www/html",
		"sudo rm -rf /var/www/html/*",
		"sudo git clone https://github.com/mr-busybones/terra.git /var/www/html",
		"sudo systemctl restart httpd",
		"sudo systemctl enable httpd",
		]
	}
}

//CREATING A S3 ORIGIN

resource "aws_s3_bucket" "mypokedex" {
  region= "ap-south-1"
  bucket = "chamanpokedex1"
  acl    = "public-read"
  force_destroy= true
  tags = {
    Name = "poke"
  }
}
locals {
  s3_origin_id = "mys3"
}

resource "aws_s3_bucket_object" "bulbasaur" {
  depends_on= [
  		aws_s3_bucket.mypokedex, 
  		]
  bucket = "chamanpokedex1"

  key    = "bulbasaur_p"
  source = "C:/Users/Chaman Goel/Desktop/terra_files/hw1/001Bulbasaur.png"
  }
  resource "aws_s3_bucket_object" "squirtle" {
  depends_on= [
  		aws_s3_bucket.mypokedex, 
  		]
  bucket = "chamanpokedex1"

  key    = "squirtle_p"
  source = "C:/Users/Chaman Goel/Desktop/terra_files/hw1/a.png"
  }
  resource "aws_s3_bucket_object" "charmeleon" {
  depends_on= [
  		aws_s3_bucket.mypokedex, 
  		]
  bucket = "chamanpokedex1"

  key    = "charmaleon_p"
  source = "C:/Users/Chaman Goel/Desktop/terra_files/hw1/b.png"
  }


resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "This is origin access identity"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
    depends_on= [
      aws_s3_bucket.mypokedex, 
      ]
  origin {
    domain_name = "${aws_s3_bucket.mypokedex.bucket_regional_domain_name}"
    origin_id   = "mys3"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "mys3"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


