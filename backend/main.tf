
#-----------------------------------------
# Create bucket to store Terraform state 
#---------------------------------------

resource "google_storage_bucket" "default" {
  name          = "terraform_state_bucket55"
  project = "crcbackend2"
  force_destroy = false
  location      = "US"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }

}

#----------------------------------
#Create the website storage buckett
#and upload webpage files 
#----------------------------------

resource "google_storage_bucket" "my_website_bucket55" {

  project = "crcfrontend2"

  name          = "my_website_bucket55"
  location      = "US"
  storage_class = "STANDARD"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "errorpage.html"
  }
}

resource "google_storage_bucket_object" "indexpage" {
  name         = "index.html"
  source      = "resumes/index.html"
  content_type = "text/html"
  bucket       = google_storage_bucket.my_website_bucket55.id
}

resource "google_storage_bucket_object" "errorpage" {
  name         = "errorpage.html"
  source       = "resumes/errorpage.html"
  content_type = "text/html"
  bucket       = google_storage_bucket.my_website_bucket55.id
}


#------------------------------------------------------
# Make bucket public by granting allUsers READER access
#------------------------------------------------------

resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.my_website_bucket55.id
  role   = "READER"
  entity = "allUsers"
}

#---------------------------------
#SSL Certificate and Load Balancer
#----------------------------------

#Create SSL Certificate
resource "google_compute_managed_ssl_certificate" "lb_default" {
  name     = "myservice-ssl-cert"
  project = "crcfrontend2"

  managed {
    domains = ["ceja.me"]
  }
}

# Reserve IP address
resource "google_compute_global_address" "default" {
  name = "example-ip"
  project =  "crcfrontend2"

}

# Create LB backend buckets
resource "google_compute_backend_bucket" "bucket_1" {
  name        = "website"
  description = "Contains CRC website files"
  project =  "crcfrontend2"

  bucket_name = google_storage_bucket.my_website_bucket55.name
}

# Create url map
resource "google_compute_url_map" "default" {
  name = "http-lb"
  project =  "crcfrontend2"
  default_service = google_compute_backend_bucket.bucket_1.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "ceja"
  }
  path_matcher {
    name            = "ceja"
    default_service = google_compute_backend_bucket.bucket_1.id

    path_rule {
      paths   = ["/index.html"]
      service = google_compute_backend_bucket.bucket_1.id
    }
  }
}

#HTTP target proxy 
resource "google_compute_target_http_proxy" "default" {
  name    = "http-lb-proxy"
  url_map = google_compute_url_map.default.id
  project =  "crcfrontend2"

}

#HTTPS proxy 
resource "google_compute_target_https_proxy" "lb_default" {
  name     = "myservice-https-proxy"
  url_map  = google_compute_url_map.default.id
  project               = "crcfrontend2"
  ssl_certificates = [
    google_compute_managed_ssl_certificate.lb_default.name
  ]
}

# Create forwarding https rule
resource "google_compute_global_forwarding_rule" "https-lb-forwarding-rule" {
  name                  = "https-lb-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  project               = "crcfrontend2"
  target                = google_compute_target_https_proxy.lb_default.id
  ip_address            = google_compute_global_address.default.id
}


#--------------------------------------------------
# Deploy Cloud Function to serve as website counter 
#-------------------------------------------------

resource "google_storage_bucket" "my_function_bucket" {
  project = "crcbackend2"

  name          = "my_function_bucket"
  location      = "US"
  storage_class = "STANDARD"

   cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_object" "my_func" {
  name         = "my_func"
  source       = "function-source.zip"
  bucket       = google_storage_bucket.my_function_bucket.id
}


resource "google_cloudfunctions_function" "function-1" {
  name        = "function-1"
  description = "http trigerred cloud function to update datastore"
  runtime     = "python311"
  project        = "crcbackend2"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.my_function_bucket.name
  source_archive_object = google_storage_bucket_object.my_func.name
  trigger_http          = true
  entry_point           = "test"
}

#-----------------------------------------------
# IAM entry for all users to invoke the function
#------------------------------------------------

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function-1.project
  region         = google_cloudfunctions_function.function-1.region
  cloud_function = google_cloudfunctions_function.function-1.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

#--------------------
# API gateway 
#--------------------

resource "google_api_gateway_api" "api_gw" {
  provider = google-beta
  api_id = "my-api"
  project =  "crcbackend2"
}

resource "google_api_gateway_api_config" "api_cfg" {
  provider = google-beta
  api = google_api_gateway_api.api_gw.api_id
  api_config_id = "my-config"
  project =  "crcbackend2"


  openapi_documents {
    document {
      path = "my-api.yaml"
      contents = filebase64("my-api.yaml")
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "api_gw" {
  provider = google-beta
  api_config = google_api_gateway_api_config.api_cfg.id
  gateway_id = "my-gateway"
  project =  "crcbackend2"
  region = "us-central1"

}

