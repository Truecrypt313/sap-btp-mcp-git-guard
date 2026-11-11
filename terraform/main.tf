terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "= 1.28.0"
    }
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "= 1.18.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "btp" {
  globalaccount = "bc5c4931trial-ga"
}

resource "btp_subaccount" "dev_project_abc" {
  name      = "DEV Project ABC"
  subdomain = "dev-project-abc-906890de-f71b-1515-31a1-672a2146ccdb"
  region    = "us10"
  labels = {
    costcenter = ["12345"]
    stage      = ["DEV"]
  }
}
