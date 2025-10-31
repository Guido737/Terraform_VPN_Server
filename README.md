# Terraform VPN Server

This repository contains Terraform configuration files for deploying a WireGuard VPN server on AWS.

## Overview
The setup automates:
- EC2 instance provisioning
- WireGuard installation and configuration
- Key generation and S3 storage for client configs
- Optional management scripts

## Requirements
- Terraform >= 1.6
- AWS account and credentials
- SSH key pair for server access

## Usage
```bash
terraform init
terraform plan
terraform apply
