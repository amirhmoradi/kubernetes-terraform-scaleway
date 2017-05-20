# Kubernetes on Scaleway via Terraform, by [Amir H. Moradi](https://www.linkedin.com/in/amirhmoradi/) , heavily inspired by [Edouard Bonlieu](https://github.com/edouardb/)'s works.

Terraform scripts for [Scaleway](https://scaleway.com), to launch a [Kuberetes](https://kubernetes.io/) cluster.

##### Getting started:

Clone or download repo.

Copy `terraform.tfvars.example` to `terraform.tfvars` and configure your variables.

Create SSH KEYS, private key named `cluster-key_rsa` and public key named `cluster-key_rsa.pub`in the same folder.

First check with `terraform plan`

Then run with `terraform apply`
