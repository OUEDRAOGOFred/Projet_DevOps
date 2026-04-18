terraform {
  required_version = ">= 1.3.0"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.60.0"
    }
  }

  # Stockage sécurisé et distant du Terraform state sur Huawei Cloud OBS (Object Storage Service)
  # Le backend "s3" est compatible avec l'API S3 standard utilisée par OBS.
  backend "s3" {
    bucket   = "devsecops-terraform-state-bucket"
    key      = "prod/infrastructure.tfstate"
    region   = "eu-west-101" # À adapter
    endpoint = "obs.eu-west-101.myhuaweicloud.com"
    # L'authentification se fait via les variables d'environnement (AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY mapped to Huawei AK/SK)
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

provider "huaweicloud" {
  region = var.region
}
