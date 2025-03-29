terraform {
  backend "s3" {
    bucket = "eksterrabucketvikas"
    key    = "backend/ToDo-App.tfstate"
    region = "us-east-1"
    dynamodb_table = "dynamoDB-vikas"
  }
}