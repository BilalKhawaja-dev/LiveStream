# Glue Data Catalog Module for Centralized Logging Infrastructure

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# Glue Database for Streaming Logs
resource "aws_glue_catalog_database" "streaming_logs" {
  name        = "${var.project_name}_logs_${var.environment}"
  description = "Glue database for streaming application logs - ${var.project_name} ${var.environment}"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-logs-${var.environment}"
    Purpose     = "Log analytics and querying"
    Environment = var.environment
  })
}

# IAM Role for Glue Crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "${var.project_name}-glue-crawler-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-glue-crawler-${var.environment}"
  })
}

# IAM Policy for Glue Crawler S3 Access
resource "aws_iam_policy" "glue_crawler_s3_policy" {
  name        = "${var.project_name}-glue-crawler-s3-${var.environment}"
  description = "IAM policy for Glue Crawler S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.s3_logs_bucket_arn,
          "${var.s3_logs_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-glue-crawler-s3-${var.environment}"
  })
}

# Attach AWS managed Glue service role policy
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Attach custom S3 policy to Glue Crawler role
resource "aws_iam_role_policy_attachment" "glue_crawler_s3_policy" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = aws_iam_policy.glue_crawler_s3_policy.arn
}

# Glue Crawler for Streaming Logs
resource "aws_glue_crawler" "streaming_logs_crawler" {
  database_name = aws_glue_catalog_database.streaming_logs.id
  name          = "${var.project_name}-logs-crawler-${var.environment}"
  role          = aws_iam_role.glue_crawler_role.arn
  description   = "Crawler for streaming application logs with automatic schema detection"

  s3_target {
    path = "s3://${var.s3_logs_bucket_name}/"
    
    # Exclude error and processed directories from crawling
    exclusions = [
      "errors/**",
      "processed/**"
    ]
  }

  # Development-optimized schedule - daily crawling
  schedule = var.crawler_schedule

  # Schema change policy for development environment
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  # Recrawl policy for cost optimization
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  # Configuration for partition detection
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-logs-crawler-${var.environment}"
    Purpose     = "Automatic schema detection for log analytics"
    Environment = var.environment
  })
}

# Glue Table for Application Logs with Partition Projection
resource "aws_glue_catalog_table" "application_logs" {
  name          = "application_logs"
  database_name = aws_glue_catalog_database.streaming_logs.id
  description   = "Application logs table with partition projection for cost optimization"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                     = "json"
    "compressionType"                   = "gzip"
    "typeOfData"                        = "file"
    "projection.enabled"                = "true"
    "projection.year.type"              = "integer"
    "projection.year.range"             = "2024,2030"
    "projection.year.interval"          = "1"
    "projection.month.type"             = "integer"
    "projection.month.range"            = "1,12"
    "projection.month.interval"         = "1"
    "projection.month.digits"           = "2"
    "projection.day.type"               = "integer"
    "projection.day.range"              = "1,31"
    "projection.day.interval"           = "1"
    "projection.day.digits"             = "2"
    "projection.hour.type"              = "integer"
    "projection.hour.range"             = "0,23"
    "projection.hour.interval"          = "1"
    "projection.hour.digits"            = "2"
    "storage.location.template"         = "s3://${var.s3_logs_bucket_name}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/application-logs/"
  }

  storage_descriptor {
    location      = "s3://${var.s3_logs_bucket_name}/application-logs/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json-serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "service"
      type = "string"
    }

    columns {
      name = "category"
      type = "string"
    }

    columns {
      name = "level"
      type = "string"
    }

    columns {
      name = "message"
      type = "string"
    }

    columns {
      name = "metadata"
      type = "struct<request_id:string,user_id:string,session_id:string,ip_address:string,user_agent:string>"
    }

    columns {
      name = "metrics"
      type = "struct<latency_ms:int,memory_usage_mb:int,cpu_usage_percent:int>"
    }

    compressed = true
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "string"
  }
}

# Glue Table for Security Events with Partition Projection
resource "aws_glue_catalog_table" "security_events" {
  name          = "security_events"
  database_name = aws_glue_catalog_database.streaming_logs.id
  description   = "Security events table with partition projection"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                     = "json"
    "compressionType"                   = "gzip"
    "typeOfData"                        = "file"
    "projection.enabled"                = "true"
    "projection.year.type"              = "integer"
    "projection.year.range"             = "2024,2030"
    "projection.year.interval"          = "1"
    "projection.month.type"             = "integer"
    "projection.month.range"            = "1,12"
    "projection.month.interval"         = "1"
    "projection.month.digits"           = "2"
    "projection.day.type"               = "integer"
    "projection.day.range"              = "1,31"
    "projection.day.interval"           = "1"
    "projection.day.digits"             = "2"
    "projection.hour.type"              = "integer"
    "projection.hour.range"             = "0,23"
    "projection.hour.interval"          = "1"
    "projection.hour.digits"            = "2"
    "storage.location.template"         = "s3://${var.s3_logs_bucket_name}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/security-events/"
  }

  storage_descriptor {
    location      = "s3://${var.s3_logs_bucket_name}/security-events/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json-serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "service"
      type = "string"
    }

    columns {
      name = "event_type"
      type = "string"
    }

    columns {
      name = "user_id"
      type = "string"
    }

    columns {
      name = "ip_address"
      type = "string"
    }

    columns {
      name = "success"
      type = "boolean"
    }

    columns {
      name = "details"
      type = "string"
    }

    compressed = true
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "string"
  }
}

# Glue Table for Performance Metrics with Partition Projection
resource "aws_glue_catalog_table" "performance_metrics" {
  name          = "performance_metrics"
  database_name = aws_glue_catalog_database.streaming_logs.id
  description   = "Performance metrics table with partition projection"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                     = "json"
    "compressionType"                   = "gzip"
    "typeOfData"                        = "file"
    "projection.enabled"                = "true"
    "projection.year.type"              = "integer"
    "projection.year.range"             = "2024,2030"
    "projection.year.interval"          = "1"
    "projection.month.type"             = "integer"
    "projection.month.range"            = "1,12"
    "projection.month.interval"         = "1"
    "projection.month.digits"           = "2"
    "projection.day.type"               = "integer"
    "projection.day.range"              = "1,31"
    "projection.day.interval"           = "1"
    "projection.day.digits"             = "2"
    "projection.hour.type"              = "integer"
    "projection.hour.range"             = "0,23"
    "projection.hour.interval"          = "1"
    "projection.hour.digits"            = "2"
    "storage.location.template"         = "s3://${var.s3_logs_bucket_name}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/performance-metrics/"
  }

  storage_descriptor {
    location      = "s3://${var.s3_logs_bucket_name}/performance-metrics/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json-serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "service"
      type = "string"
    }

    columns {
      name = "metric_name"
      type = "string"
    }

    columns {
      name = "metric_value"
      type = "double"
    }

    columns {
      name = "unit"
      type = "string"
    }

    columns {
      name = "dimensions"
      type = "map<string,string>"
    }

    compressed = true
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "string"
  }
}

# Glue Table for User Activity with Partition Projection
resource "aws_glue_catalog_table" "user_activity" {
  name          = "user_activity"
  database_name = aws_glue_catalog_database.streaming_logs.id
  description   = "User activity table with partition projection"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                     = "json"
    "compressionType"                   = "gzip"
    "typeOfData"                        = "file"
    "projection.enabled"                = "true"
    "projection.year.type"              = "integer"
    "projection.year.range"             = "2024,2030"
    "projection.year.interval"          = "1"
    "projection.month.type"             = "integer"
    "projection.month.range"            = "1,12"
    "projection.month.interval"         = "1"
    "projection.month.digits"           = "2"
    "projection.day.type"               = "integer"
    "projection.day.range"              = "1,31"
    "projection.day.interval"           = "1"
    "projection.day.digits"             = "2"
    "projection.hour.type"              = "integer"
    "projection.hour.range"             = "0,23"
    "projection.hour.interval"          = "1"
    "projection.hour.digits"            = "2"
    "storage.location.template"         = "s3://${var.s3_logs_bucket_name}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/user-activity/"
  }

  storage_descriptor {
    location      = "s3://${var.s3_logs_bucket_name}/user-activity/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json-serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "user_id"
      type = "string"
    }

    columns {
      name = "session_id"
      type = "string"
    }

    columns {
      name = "activity_type"
      type = "string"
    }

    columns {
      name = "stream_id"
      type = "string"
    }

    columns {
      name = "duration_seconds"
      type = "int"
    }

    columns {
      name = "quality"
      type = "string"
    }

    columns {
      name = "device_type"
      type = "string"
    }

    compressed = true
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "string"
  }
}

# Glue Table for System Changes with Partition Projection
resource "aws_glue_catalog_table" "system_changes" {
  name          = "system_changes"
  database_name = aws_glue_catalog_database.streaming_logs.id
  description   = "System changes table with partition projection"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                     = "json"
    "compressionType"                   = "gzip"
    "typeOfData"                        = "file"
    "projection.enabled"                = "true"
    "projection.year.type"              = "integer"
    "projection.year.range"             = "2024,2030"
    "projection.year.interval"          = "1"
    "projection.month.type"             = "integer"
    "projection.month.range"            = "1,12"
    "projection.month.interval"         = "1"
    "projection.month.digits"           = "2"
    "projection.day.type"               = "integer"
    "projection.day.range"              = "1,31"
    "projection.day.interval"           = "1"
    "projection.day.digits"             = "2"
    "projection.hour.type"              = "integer"
    "projection.hour.range"             = "0,23"
    "projection.hour.interval"          = "1"
    "projection.hour.digits"            = "2"
    "storage.location.template"         = "s3://${var.s3_logs_bucket_name}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/system-changes/"
  }

  storage_descriptor {
    location      = "s3://${var.s3_logs_bucket_name}/system-changes/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json-serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "change_type"
      type = "string"
    }

    columns {
      name = "service"
      type = "string"
    }

    columns {
      name = "component"
      type = "string"
    }

    columns {
      name = "change_description"
      type = "string"
    }

    columns {
      name = "initiated_by"
      type = "string"
    }

    columns {
      name = "success"
      type = "boolean"
    }

    compressed = true
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "string"
  }
}