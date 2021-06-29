terraform {
  backend "s3" {
    bucket = "dferristempstorage"
    key    = "tfdemo.state"
    region = "ap-southeast-2"
  }
}
