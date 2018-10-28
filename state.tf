terraform {
  backend "s3" {
    bucket  = "invictrix-terraform"
    key     = "invictrix_site.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "invictrix"
  }
}

data "terraform_remote_state" "state" {
  backend = "s3"

  config {
    bucket  = "invictrix-terraform"
    key     = "invictrix_site.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "invictrix"
  }
}
