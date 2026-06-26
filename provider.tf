provider "aws" {
  
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">5.0" #morthan 4.0 version
    }
  }
}
