terraform {
  backend "s3" {
    bucket = "check-in-bucks89"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}
