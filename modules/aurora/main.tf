# Aurora Serverless v2 Module
# Requirements: 3.1, 4.1, 4.7, 3.5, 5.1, 4.8, 5.6

# Aurora module now receives VPC information from the VPC module
# No need for data sources since VPC info is passed as variables

# Security group is passed as a variable from the VPC module

# KMS key for Aurora encryption
resource "aws_kms_key" "aurora" {
  description             = "KMS key for Aurora cluster encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-key"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.project_name}-${var.environment}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

# DB subnet group for Aurora
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-subnet-group"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Random password for Aurora master user
resource "random_password" "aurora_master" {
  length  = 16
  special = true
}

# Store Aurora master password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "aurora_master" {
  name                    = "${var.project_name}-${var.environment}-aurora-master-password"
  description             = "Aurora master user password"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = aws_kms_key.aurora.arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-master-password"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

resource "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = aws_secretsmanager_secret.aurora_master.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.aurora_master.result
  })
}

# Aurora Serverless v2 cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier          = "${var.project_name}-${var.environment}-aurora-cluster"
  engine                      = "aurora-mysql"
  engine_version              = var.engine_version
  engine_mode                 = "provisioned"
  database_name               = var.database_name
  master_username             = var.master_username
  manage_master_user_password = false
  master_password             = random_password.aurora_master.result

  # Backup configuration
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  copy_tags_to_snapshot        = true
  delete_automated_backups     = var.environment != "prod"

  # Security and encryption
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.aurora.arn
  vpc_security_group_ids = [var.aurora_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.aurora.name

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  # Monitoring and logging
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? aws_kms_key.aurora.arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Network and availability
  availability_zones = var.availability_zones
  port               = var.port

  # Deletion protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Apply changes immediately in development
  apply_immediately = var.environment != "prod"

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-cluster"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }

  depends_on = [
    aws_cloudwatch_log_group.aurora_logs
  ]
}

# Aurora Serverless v2 cluster instances
resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = var.instance_count
  identifier         = "${var.project_name}-${var.environment}-aurora-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? aws_kms_key.aurora.arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Apply changes immediately in development
  apply_immediately = var.environment != "prod"

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-instance-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# CloudWatch Log Groups for Aurora logs
resource "aws_cloudwatch_log_group" "aurora_logs" {
  for_each = toset(var.enabled_cloudwatch_logs_exports)

  name              = "/aws/rds/cluster/${var.project_name}-${var.environment}-aurora-cluster/${each.value}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.aurora.arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-${each.value}-logs"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Enhanced monitoring IAM role (conditional)
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.project_name}-${var.environment}-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-enhanced-monitoring-role"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms for Aurora Monitoring
# Requirements: 4.8, 5.6

# SNS topic for Aurora alarms (if not provided)
resource "aws_sns_topic" "aurora_alarms" {
  count = var.enable_cloudwatch_alarms && var.sns_topic_arn == "" ? 1 : 0

  name              = "${var.project_name}-${var.environment}-aurora-alarms"
  display_name      = "Aurora Database Alarms"
  kms_master_key_id = aws_kms_key.aurora.arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-alarms"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

locals {
  sns_topic_arn = var.sns_topic_arn != "" ? var.sns_topic_arn : (var.enable_cloudwatch_alarms ? aws_sns_topic.aurora_alarms[0].arn : "")
}

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_cpu_utilization" {
  count = var.enable_cloudwatch_alarms ? var.instance_count : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-cpu-utilization-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  alarm_description   = "This metric monitors Aurora instance CPU utilization"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.aurora_instances[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-cpu-alarm-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Database Connection Count Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_database_connections" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-database-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_connection_threshold
  alarm_description   = "This metric monitors Aurora cluster database connections"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-connections-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Freeable Memory Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_freeable_memory" {
  count = var.enable_cloudwatch_alarms ? var.instance_count : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-freeable-memory-${count.index + 1}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_freeable_memory_threshold
  alarm_description   = "This metric monitors Aurora instance freeable memory"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.aurora_instances[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-memory-alarm-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Aurora Serverless v2 ACU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_serverless_acu_utilization" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-acu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.max_capacity * 0.8 # 80% of max capacity
  alarm_description   = "This metric monitors Aurora Serverless v2 ACU utilization"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-acu-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Backup Failure Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_backup_failure" {
  count = var.backup_alarm_enabled ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-backup-failure"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BackupRetentionPeriodStorageUsed"
  namespace           = "AWS/RDS"
  period              = "86400" # 24 hours
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "This alarm triggers when Aurora backup fails or is missing"
  alarm_actions       = [local.sns_topic_arn]
  treat_missing_data  = "breaching"
  datapoints_to_alarm = 1

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-backup-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Read Latency Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_read_latency" {
  count = var.enable_cloudwatch_alarms ? var.instance_count : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-read-latency-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = 0.2 # 200ms
  alarm_description   = "This metric monitors Aurora instance read latency"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.aurora_instances[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-read-latency-alarm-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Write Latency Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_write_latency" {
  count = var.enable_cloudwatch_alarms ? var.instance_count : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-write-latency-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = 0.2 # 200ms
  alarm_description   = "This metric monitors Aurora instance write latency"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.aurora_instances[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-write-latency-alarm-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}

# Aurora Replica Lag Alarm (if multiple instances)
resource "aws_cloudwatch_metric_alarm" "aurora_replica_lag" {
  count = var.enable_cloudwatch_alarms && var.instance_count > 1 ? var.instance_count - 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-aurora-replica-lag-${count.index + 2}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "AuroraReplicaLag"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = 1000 # 1 second in milliseconds
  alarm_description   = "This metric monitors Aurora replica lag"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.aurora_instances[count.index + 1].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-replica-lag-alarm-${count.index + 2}"
    Environment = var.environment
    Project     = var.project_name
    Service     = "aurora"
  }
}