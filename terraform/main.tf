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
# EGRESS PRIVATELINK GATEWAY — for connectors to reach external AWS services (e.g. S3)
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

resource "time_sleep" "wait_for_egress_gateway" {
  depends_on      = [
    confluent_gateway.non_prod_egress
  ]
  
  create_duration = "2m"
}

# ===================================================================================
# EGRESS ACCESS POINT — S3 Sink Connector via PrivateLink
# ===================================================================================
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
    enable_high_availability  = false  # set true for multi-AZ redundancy
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