# IaC Confluent Cloud AWS Egress Private Linking, Infrastructure and Networking Example
This Terraform workspace provisions the **Confluent Cloud Egress PrivateLink** infrastructure that enables Enterprise Kafka cluster connectors (e.g., S3 Sink Connector) to reach external AWS services over private networking — without traversing the public internet.

It is a downstream workspace that depends on the environment ID output from the [ingress PrivateLink workspace](https://github.com/signalroom/iac-cc-aws-privatelink-infrastructure-networking-example).

> **Terraform Cloud Workspace:** `iac-cc-aws-egress-privatelink-infrastructure-networking-example`
> **Organization:** `signalroom`

---

## Table of Contents
<!-- toc -->
<!-- tocstop -->


1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Workspace Dependencies](#workspace-dependencies)
5. [Resources Provisioned](#resources-provisioned)
6. [Input Variables](#input-variables)
7. [Outputs](#outputs)
8. [Usage](#usage)
9. [Post-Apply: S3 Bucket Policy](#post-apply-s3-bucket-policy)
10. [Adding More Egress Endpoints](#adding-more-egress-endpoints)

---

## **1.0 Overview**
This repo contains Terraform code to provision Confluent Cloud PrivateLink infrastructure for both ingress and egress connectivity.

---

## **2.0 Architecture**

```mermaid
flowchart TB
    subgraph TFC["Terraform Cloud — signalroom"]
        direction TB
        WS1["Workspace: iac-cc-aws-privatelink-infrastructure-networking-example\n(Ingress — upstream)"]
        WS2["Workspace: iac-cc-aws-egress-privatelink-infrastructure-networking-example\n(Egress — this workspace)"]
        WS1 -- "output: non_prod_environment_id\n→ var: confluent_environment_id" --> WS2
    end

    subgraph CCLOUD["Confluent Cloud — non-prod Environment"]
        direction TB
        ENV["confluent_environment\nnon_prod"]

        subgraph INGRESS_GW["Ingress Gateway (upstream workspace)"]
            IGW["confluent_gateway\naws_ingress_private_link_gateway"]
        end

        subgraph EGRESS_GW["Egress Gateway (this workspace)"]
            EGW["confluent_gateway\nnon_prod_egress\naws_egress_private_link_gateway"]
            SLEEP["time_sleep\n2 min provisioning wait"]
            AP["confluent_access_point\negress_s3\naws_egress_private_link_endpoint\ncom.amazonaws.REGION.s3"]
            DNS["confluent_dns_record\negress_s3\ns3.REGION.amazonaws.com"]

            EGW --> SLEEP --> AP --> DNS
        end

        subgraph CLUSTERS["Enterprise Kafka Clusters"]
            SC["sandbox_cluster"]
            SHC["shared_cluster"]
        end

        ENV --> IGW
        ENV --> EGW
        SC -. "uses egress gateway\nfor connector outbound" .-> EGW
        SHC -. "uses egress gateway\nfor connector outbound" .-> EGW
    end

    subgraph AWS["AWS — same region as Confluent gateway"]
        subgraph VPCE["AWS Interface VPC Endpoint"]
            EP["VPC Endpoint\ncom.amazonaws.REGION.s3\n(provisioned by Confluent via IAM principal)"]
        end

        subgraph S3["Amazon S3"]
            BUCKET["S3 Bucket\nBucket Policy:\n• Principal: egress_gateway_iam_principal\n• Condition: aws:sourceVpce"]
        end

        EP --> BUCKET
    end

    AP -- "Confluent creates\nVPC endpoint via\nIAM principal ARN" --> EP
    DNS -- "CNAME →\nVPC endpoint DNS name" --> EP

    subgraph OUTPUTS["Terraform Outputs"]
        O1["egress_gateway_id"]
        O2["egress_gateway_iam_principal\n→ S3 bucket policy Principal"]
        O3["egress_s3_access_point_id"]
        O4["egress_s3_vpc_endpoint_id\n→ S3 bucket policy aws:sourceVpce"]
    end

    EGW --> O1
    EGW --> O2
    AP --> O3
    AP --> O4

    style TFC fill:#f5f0ff,stroke:#7c3aed,color:#1a1a1a
    style CCLOUD fill:#e8f4fd,stroke:#0066cc,color:#1a1a1a
    style AWS fill:#fff3e0,stroke:#e65100,color:#1a1a1a
    style OUTPUTS fill:#e8f5e9,stroke:#2e7d32,color:#1a1a1a
    style EGRESS_GW fill:#dbeafe,stroke:#1d4ed8,color:#1a1a1a
    style INGRESS_GW fill:#ede9fe,stroke:#6d28d9,color:#1a1a1a
    style CLUSTERS fill:#fce7f3,stroke:#9d174d,color:#1a1a1a
    style VPCE fill:#fff7ed,stroke:#c2410c,color:#1a1a1a
    style S3 fill:#fef3c7,stroke:#b45309,color:#1a1a1a
```

---
