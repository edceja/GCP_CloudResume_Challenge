
provider "google" {
  credentials = "${file("./creds/SAKEY.json")}"
  project = "crcbackend2"
  region  = "us-central1"
  zone    = "us-central1-c"
}

provider "google-beta" {
  credentials = "${file("./creds/SAKEY.json")}"
  project = "crcbackend2"
  region  = "us-central1"
  zone    = "us-central1-c"
}