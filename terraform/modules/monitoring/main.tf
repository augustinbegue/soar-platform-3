locals {
  tags = {
    Component = "monitoring"
    Name      = var.name_prefix
  }
}

# ========================================
# CloudWatch Dashboard
# ========================================

resource "aws_cloudwatch_dashboard" "ecs_monitoring" {
  dashboard_name = "${var.name_prefix}-ecs-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "Total Requests" }],
            [".", "TargetResponseTime", ".", ".", { stat = "Average", label = "Response Time (avg)" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", { stat = "Sum", label = "2XX Responses" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4XX Responses" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5XX Responses" }],
          ]
          period  = 60
          region  = data.aws_region.current.id
          title   = "ALB Request Count & Response Time"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "Active Connections" }],
            [".", "NewConnectionCount", ".", ".", { stat = "Sum", label = "New Connections" }],
            [".", "ProcessedBytes", ".", ".", { stat = "Sum", label = "Processed Bytes" }],
          ]
          period  = 60
          region  = data.aws_region.current.id
          title   = "ALB Connection Metrics"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "CPU Utilized" }],
            [".", "CpuReserved", ".", ".", ".", ".", { stat = "Average", label = "CPU Reserved" }],
            [".", "MemoryUtilized", ".", ".", ".", ".", { stat = "Average", label = "Memory Utilized (MB)" }],
            [".", "MemoryReserved", ".", ".", ".", ".", { stat = "Average", label = "Memory Reserved (MB)" }],
          ]
          period  = 60
          region  = data.aws_region.current.id
          title   = "ECS Service Resource Utilization (Container Insights)"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ECS/ContainerInsights", "DesiredTaskCount", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Desired Tasks" }],
            [".", "RunningTaskCount", ".", ".", ".", ".", { stat = "Average", label = "Running Tasks" }],
            [".", "PendingTaskCount", ".", ".", ".", ".", { stat = "Average", label = "Pending Tasks" }],
          ]
          period  = 60
          region  = data.aws_region.current.id
          title   = "ECS Service Task Count"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "Healthy Hosts" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", label = "Unhealthy Hosts" }],
          ]
          period  = 60
          region  = data.aws_region.current.id
          title   = "Target Group Health Status"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ECS/ContainerInsights", "NetworkRxBytes", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Network RX (bytes)" }],
            [".", "NetworkTxBytes", ".", ".", ".", ".", { stat = "Average", label = "Network TX (bytes)" }],
          ]
          period  = 60
          region  = data.aws_region.current.id
          title   = "ECS Network I/O (Container Insights)"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          query         = "SOURCE '/ecs/${var.name_prefix}' | fields @timestamp, @message | stats count() as request_count by bin(1m)"
          region        = data.aws_region.current.id
          title         = "Request Count from Logs (1-min bins)"
          logGroupNames = ["/ecs/${var.name_prefix}"]
          view          = "timeSeries"
          stacked       = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ECS/ContainerInsights", "StorageReadBytes", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Storage Read (bytes)" }],
            [".", "StorageWriteBytes", ".", ".", ".", ".", { stat = "Average", label = "Storage Write (bytes)" }],
          ]
          period  = 60
          region  = data.aws_region.current.id
          title   = "ECS Storage I/O (Container Insights)"
          view    = "timeSeries"
          stacked = false
        }
      },
    ]
  })
}

# ========================================
# CloudWatch Alarms for Request Rate
# ========================================

# Alarm for high request rate
resource "aws_cloudwatch_metric_alarm" "alb_high_request_rate" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-high-request-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_high_request_rate_threshold
  alarm_description   = "Alert when ALB request count exceeds ${var.alb_high_request_rate_threshold} in 5 minutes"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-high-request-rate"
  })
}

# Alarm for high response time
resource "aws_cloudwatch_metric_alarm" "alb_high_response_time" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.alb_high_response_time_threshold
  alarm_description   = "Alert when average response time exceeds ${var.alb_high_response_time_threshold} seconds"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-high-response-time"
  })
}

# Alarm for high HTTP 5XX error rate
resource "aws_cloudwatch_metric_alarm" "alb_high_5xx_rate" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-high-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_high_5xx_threshold
  alarm_description   = "Alert when 5XX error count exceeds ${var.alb_high_5xx_threshold} in 5 minutes"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-high-5xx-error-rate"
  })
}

# ========================================
# CloudWatch Alarms for ECS Auto-scaling
# ========================================

# Alarm for when scaling occurs due to request count
resource "aws_cloudwatch_metric_alarm" "ecs_scaling_activity" {
  count = var.enable_alarms && var.ecs_autoscaling_group_name != "" ? 1 : 0

  alarm_name          = "${var.name_prefix}-ecs-scaling-activity"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupDesiredCapacity"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = var.ecs_min_capacity + 1
  alarm_description   = "Alert when ECS service scales beyond minimum capacity"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.ecs_autoscaling_group_name
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-ecs-scaling-activity"
  })
}

# Alarm for unhealthy targets
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when any targets become unhealthy"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-unhealthy-targets"
  })
}

# ========================================
# Data Source for AWS Region
# ========================================

data "aws_region" "current" {}
