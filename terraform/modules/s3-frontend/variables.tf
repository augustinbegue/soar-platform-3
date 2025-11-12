variable "name_prefix" {
  description = "Prefix applied to S3 bucket and resources"
  type        = string
}

variable "backend_url" {
  description = "URL of the backend API (will be injected into env.js)"
  type        = string
}
