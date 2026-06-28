terraform {
  backend "s3" {
    bucket         = "atlas-tfn-bucket"
    key            = "prod/network/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = ""
    encrypt        = true
    profile        = "slazysloth"
  }
}
