# Module that defines an AWS auto scaling group of VMs that listen to requests for jobs from Azure Pipelines (AZP).

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.61"
    }
  }
}
