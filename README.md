# 📘 `ansible-controller-config` — Ansible Config & Playbooks  


This repository contains all **Ansible configurations and playbooks** to deploy Docker containers  
(from ECR) to EC2 instances inside an Auto Scaling Group.

---

## 🚀 Features
- **Inventory**
  - Dynamic AWS EC2 inventory plugin
  - Targets EC2s in the ASG provisioned by Terraform
- **Playbooks**
  - Install Docker, dependencies, AWS CLI
  - Authenticate to ECR
  - Pull Docker image by tag
  - Start/replace Nginx container
- **Secrets**
  - Managed using Ansible Vault + AWS Secrets Manager
  - Vault password retrieved securely from Secrets Manager at runtime

---

## 📂 Structure
ansible-controller-config/
├── ansible.cfg
├── inventories/
│ └── aws_ec2.yml
├── group_vars/
│ └── all/
│ └── vault.yml (encrypted)
├── playbooks/
│ └── deploy.yml
└── roles/
├── docker/
└── nginx/