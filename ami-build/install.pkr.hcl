
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.1"
      source = "github.com/hashicorp/amazon"
    }
  }
}
