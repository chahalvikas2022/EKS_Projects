terraform {
  backend "s3" {
    bucket = "eksterrabucket2025"
    key    = "backend/ToDo-App.tfstate"
    region = "us-east-1"
    dynamodb_table = "dynamo-vikas"
  }
}