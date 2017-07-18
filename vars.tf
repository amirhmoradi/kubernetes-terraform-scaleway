variable "organization_key" {
  description = "Scaleway access_key"
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "secret_key" {
  description = "Scaleway secret_key"
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "region" {
  description = "Scaleway region: Paris (PAR1) or Amsterdam (AMS1)"
  default     = "ams1"
}

variable "architecture" {
  description = "Architecture x86_64 or arm"
  default     = "x86_64"
}

variable "user" {
  description = "Username to connect the server"
  default     = "root"
}

variable "dynamic_ip" {
  description = "Enable or disable server dynamic public ip"
  default     = "true"
}

variable "base_image_id" {
  description = "Scaleway image ID"
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "base_bootscript_id" {
  description = "Scaleway bootscript ID"
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "scaleway_boot_type" {
  description = "Instance type of bootstrap unit"
  default     = "VC1S"
}

variable "scaleway_master_type" {
  description = "Instance type of Master"
  default     = "VC1S"
}

variable "scaleway_agent_type" {
  description = "Instance type of Agent"
  default     = "VC1S"
}

variable "cluster_os" {
  description = "Name of your cluster OS. Alpha-numeric and hyphens only, please."
  default     = "K8S"
}

variable "cluster_name" {
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "scaleway-clustercloud"
}

variable "cluster_agent_count" {
  description = "Number of agents to deploy"
  default     = "4"
}

variable "cluster_token" {
  description = "Token used to secure cluster boostrap"
  default     = "cef4cf.a9e2d6e46c2d4d49"
}

variable "cluster_master_count" {
  default     = "3"
  description = "Number of master nodes. 1, 3, or 5."
}

variable "agent_count" {
  description = "Number of agents to deploy"
  default     = "4"
}

variable "public_agent_count" {
  description = "Number of public agents to deploy"
  default     = "1"
}

variable "user_ssh_public_key_path" {
  description = "Path to your public SSH key path"
  default     = "./scw.pub"
}

variable "user_ssh_key_path" {
  description = "Path to your private SSH key for the project"
  default     = "./scw"
}

variable "cluster_master_port" {
  description = "Bootstrap custom port (use more than 1025)"
  default     = ["50001"]
}
