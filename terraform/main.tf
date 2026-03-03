terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "iac-cc-aws-egress-privatelink-infrastructure-networking-example"
        }
    }

    required_providers {
      confluent = {
        source  = "confluentinc/confluent"
        version = "2.62.0"
      }
      time = {
        source  = "hashicorp/time"
        version = "~> 0.13.1"
      }
    }
}


# =======================================================================================
# CONFLUENT — EGRESS PRIVATELINK GATEWAY
#
# One egress gateway per AWS region per environment is allowed. It is shared across
# all Enterprise clusters in the non-prod environment and serves as the anchor for
# both the JDBC and S3 egress access points below.
#
# The gateway exposes a unique IAM principal ARN after provisioning. For JDBC, this
# ARN is set in aws_vpc_endpoint_service.allowed_principals — automating the
# "Allow Confluent principal" step from the setup guide. For S3, no allowlist is
# needed since S3 is a native AWS PrivateLink service.
# =======================================================================================
resource "confluent_gateway" "non_prod_egress" {
  display_name = "${data.confluent_environment.non_prod.display_name}-egress-privatelink-gateway"

  environment {
    id = data.confluent_environment.non_prod.id
  }

  aws_egress_private_link_gateway {
    region = var.aws_region
  }
}

# Allow 2 minutes for the Confluent control plane to fully provision the gateway
# before any dependent resources attempt to use it.
resource "time_sleep" "wait_for_egress_gateway" {
  depends_on      = [
    confluent_gateway.non_prod_egress
  ]

  create_duration = "2m"
}

# ======================================================================================
# S3 EGRESS — ACCESS POINT AND DNS RECORD
#
# S3 is a native AWS PrivateLink service — no NLB, no endpoint service, and no manual
# acceptance step is required. Confluent connects directly to the AWS-managed S3
# PrivateLink service name for the region.
#
# The DNS record maps s3.<region>.amazonaws.com to the VPC endpoint inside Confluent
# Cloud's network. The S3 Sink Connector uses the standard S3 endpoint hostname and
# Confluent resolves it transparently over PrivateLink.
#
# After apply, the S3 access point transitions directly to "Ready" with no manual
# steps. The S3 bucket policy must be updated separately to restrict access to
# Confluent's VPC endpoint ID (see outputs: egress_s3_vpc_endpoint_id).
# ======================================================================================
resource "confluent_access_point" "egress_s3" {
  display_name = "ccloud-egress-accesspoint-s3-${var.aws_region}"

  environment {
    id = data.confluent_environment.non_prod.id
  }

  gateway {
    id = confluent_gateway.non_prod_egress.id
  }

  aws_egress_private_link_endpoint {
    vpc_endpoint_service_name = "com.amazonaws.${var.aws_region}.s3"
    enable_high_availability  = false
  }

  depends_on = [
    time_sleep.wait_for_egress_gateway
  ]
}

resource "confluent_dns_record" "egress_s3" {
  display_name = "dns-record-s3-${var.aws_region}"

  environment {
    id = data.confluent_environment.non_prod.id
  }

  domain = "s3.${var.aws_region}.amazonaws.com"

  gateway {
    id = confluent_gateway.non_prod_egress.id
  }

  private_link_access_point {
    id = confluent_access_point.egress_s3.id
  }

  depends_on = [
    confluent_access_point.egress_s3
  ]
}

# =======================================================================================
# JDBC EGRESS — AWS INFRASTRUCTURE
#
# JDBC targets a self-managed database — AWS requires a Network Load Balancer backed
# endpoint service for any PrivateLink connection to a non-native service.
#
# Resource order:
#   Target Group + Attachment  (register database IP)
#   Security Group + Rules     (restrict traffic to database port)
#   NLB + Listener             (front the target group)
#   Endpoint Service           (expose the NLB via PrivateLink)
# =======================================================================================

# --------------------------------------------------------------------------------------
# TARGET GROUP (docs Step 2)
#
# IP address target type allows registration of any private IP — RDS, EC2, or
# on-premises. One target group per port. For multiple databases on different ports,
# add additional aws_lb_target_group + aws_lb_target_group_attachment + aws_lb_listener
# blocks and reference the same aws_lb.jdbc.
#
# Note: RDS IPs can change after failover or maintenance. For production workloads
# consider fronting RDS with PgBouncer or RDS Proxy on a stable IP.
# --------------------------------------------------------------------------------------
resource "aws_lb_target_group" "jdbc" {
  name        = "${var.nlb_name}-tg"
  port        = var.database_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.database_vpc_id

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name      = "${var.nlb_name}-tg"
    ManagedBy = "Terraform Cloud"
    Purpose   = "JDBC PrivateLink target group"
  }

  depends_on = [ 
    confluent_dns_record.egress_s3 
  ]
}

resource "aws_lb_target_group_attachment" "jdbc" {
  target_group_arn = aws_lb_target_group.jdbc.arn
  target_id        = var.database_private_ip
  port             = var.database_port

  depends_on = [
    aws_lb_target_group.jdbc
  ]
}

# --------------------------------------------------------------------------------------
# NLB SECURITY GROUP (docs Step 3)
#
# enforce_security_group_inbound_rules_on_private_link_traffic = "off" on the NLB
# (below) disables inbound rule enforcement for PrivateLink traffic at the NLB level.
# This is a Confluent prerequisite — without it, PrivateLink traffic is silently
# dropped even when the access point shows "Ready".
#
# The security group still applies to non-PrivateLink traffic. aws_security_group_rule
# resources are used instead of inline blocks to stay consistent with the ingress
# workspace pattern.
# --------------------------------------------------------------------------------------
resource "aws_security_group" "nlb_jdbc" {
  name        = "${var.nlb_name}-sg"
  description = "Security group for JDBC PrivateLink NLB"
  vpc_id      = var.database_vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "${var.nlb_name}-sg"
    ManagedBy = "Terraform Cloud"
    Purpose   = "JDBC PrivateLink NLB"
  }

  depends_on = [ 
    aws_lb_target_group_attachment.jdbc 
  ]
}

resource "aws_security_group_rule" "nlb_jdbc_ingress_db_port" {
  description       = "Database port ingress from within the VPC"
  type              = "ingress"
  from_port         = var.database_port
  to_port           = var.database_port
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.database.cidr_block]
  security_group_id = aws_security_group.nlb_jdbc.id

  depends_on = [ 
    aws_security_group.nlb_jdbc 
  ]
}

resource "aws_security_group_rule" "nlb_jdbc_egress_all" {
  description       = "Allow all outbound from NLB to database targets"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nlb_jdbc.id

  depends_on = [ 
    aws_security_group_rule.nlb_jdbc_ingress_db_port
  ]
}

# --------------------------------------------------------------------------------------
# NETWORK LOAD BALANCER (docs Step 3)
#
# Must be internal — PrivateLink endpoint services require an internal NLB.
# Cross-zone load balancing is enabled to prevent AZ-mismatch failures between
# Confluent's endpoint NICs and the NLB subnet mappings.
# --------------------------------------------------------------------------------------
resource "aws_lb" "jdbc" {
  name               = var.nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = local.database_subnet_ids
  security_groups    = [aws_security_group.nlb_jdbc.id]

  enforce_security_group_inbound_rules_on_private_link_traffic = "off"
  enable_cross_zone_load_balancing                             = true

  tags = {
    Name      = var.nlb_name
    ManagedBy = "Terraform Cloud"
    Purpose   = "JDBC PrivateLink NLB"
  }

  depends_on = [
    aws_security_group_rule.nlb_jdbc_egress_all
  ]
}

resource "aws_lb_listener" "jdbc" {
  load_balancer_arn = aws_lb.jdbc.arn
  port              = var.database_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jdbc.arn
  }

  depends_on = [ 
    aws_lb.jdbc 
  ]
}

# --------------------------------------------------------------------------------------
# VPC ENDPOINT SERVICE (docs Step 4)
#
# STEP 5 — AUTOMATED: Confluent's IAM principal ARN is set in allowed_principals,
# authorizing Confluent to create a VPC endpoint against this service. No manual
# console step needed for this step.
#
# STEP 7 — MANUAL (cannot be automated): acceptance_required = true means AWS holds
# every new endpoint connection in "Pending accept" regardless of allowed_principals.
# After terraform apply, go to:
#   AWS Console → VPC → Endpoint services → [this service] → Endpoint connections
#   → select the pending connection → Actions → Accept
# The confluent_access_point transitions from "Pending accept" to "Ready" only
# after manual acceptance.
# --------------------------------------------------------------------------------------
resource "aws_vpc_endpoint_service" "jdbc" {
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.jdbc.arn]

  allowed_principals = [
    confluent_gateway.non_prod_egress.aws_egress_private_link_gateway[0].principal_arn
  ]

  tags = {
    Name      = var.endpoint_service_name
    ManagedBy = "Terraform Cloud"
    Purpose   = "JDBC PrivateLink endpoint service for Confluent Cloud egress"
  }

  depends_on = [
    aws_lb.jdbc,
    time_sleep.wait_for_egress_gateway
  ]
}

# =======================================================================================
# JDBC EGRESS — CONFLUENT ACCESS POINT AND DNS RECORD (docs Steps 6 and 8)
#
# The access point instructs Confluent to create an Interface VPC Endpoint targeting
# the endpoint service above. High availability deploys NICs in multiple AZs —
# strongly recommended for database connectivity.
#
# The DNS record maps the database FQDN to the VPC endpoint inside Confluent Cloud's
# network. The connector uses var.database_domain as its hostname — the value here
# must exactly match the hostname in the connector's connection.url.
#
# Both resources remain in "Provisioning" until the manual AWS acceptance step
# (docs Step 7) is completed and the access point reaches "Ready".
# =======================================================================================
resource "confluent_access_point" "egress_jdbc" {
  display_name = "ccloud-egress-accesspoint-jdbc-${var.aws_region}"

  environment {
    id = data.confluent_environment.non_prod.id
  }

  gateway {
    id = confluent_gateway.non_prod_egress.id
  }

  aws_egress_private_link_endpoint {
    vpc_endpoint_service_name = aws_vpc_endpoint_service.jdbc.service_name
    enable_high_availability  = true
  }

  depends_on = [
    time_sleep.wait_for_egress_gateway,
    aws_vpc_endpoint_service.jdbc
  ]
}

resource "confluent_dns_record" "egress_jdbc" {
  display_name = "dns-record-jdbc-${var.aws_region}"

  environment {
    id = data.confluent_environment.non_prod.id
  }

  domain = var.database_domain

  gateway {
    id = confluent_gateway.non_prod_egress.id
  }

  private_link_access_point {
    id = confluent_access_point.egress_jdbc.id
  }

  depends_on = [
    confluent_access_point.egress_jdbc
  ]
}
