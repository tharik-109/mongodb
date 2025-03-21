terraform {
  backend "s3" {
    bucket         = "mongodb-tool" 
    key            = "terraform.tfstate"
    region         = "us-east-1" 
    encrypt        = true
  }
}
