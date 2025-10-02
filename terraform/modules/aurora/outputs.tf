output "cluster_arn" {
  description = "ARN of the Aurora cluster."
  value       = null
}

output "writer_endpoint" {
  description = "Writer endpoint for the Aurora cluster."
  value       = null
}

output "reader_endpoint" {
  description = "Reader endpoint for load-balanced reads."
  value       = null
}
