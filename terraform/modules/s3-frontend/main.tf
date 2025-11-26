# ========================================
# S3 Bucket for Frontend Static Website
# ========================================

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.name_prefix}-frontend"
  tags   = local.tags
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Public access settings
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy to allow public read access
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# CORS configuration for API calls
resource "aws_s3_bucket_cors_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Upload index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${path.root}/../crud_app/frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.root}/../crud_app/frontend/index.html")

  depends_on = [aws_s3_bucket_policy.frontend]
}

# Upload styles.css
resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "styles.css"
  source       = "${path.root}/../crud_app/frontend/styles.css"
  content_type = "text/css"
  etag         = filemd5("${path.root}/../crud_app/frontend/styles.css")

  depends_on = [aws_s3_bucket_policy.frontend]
}

# Upload app.js
resource "aws_s3_object" "app" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "app.js"
  source       = "${path.root}/../crud_app/frontend/app.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.root}/../crud_app/frontend/app.js")

  depends_on = [aws_s3_bucket_policy.frontend]
}

# Upload env.template.js with backend URL
resource "aws_s3_object" "env" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "env.js"
  content      = "const API_BASE = '${var.backend_url}';"
  content_type = "application/javascript"

  depends_on = [aws_s3_bucket_policy.frontend]
}

locals {
  tags = {
    Component = "s3-frontend"
    Name      = "${var.name_prefix}-frontend"
  }
}
