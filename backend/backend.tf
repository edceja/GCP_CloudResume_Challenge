terraform {
 required_version = "~>1.4.2" 
 backend "gcs" {
  credentials = "./creds/SAKEY.json"
   bucket  = "terraform_state_bucket55"
   prefix  = "terraform/state"
 }
}
