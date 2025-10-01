# 📘 `ansible-controller-config` — Ansible Config & Playbooks  

This repository contains all **Ansible configurations and playbooks** to deploy Docker containers  
(from Amazon ECR) to EC2 instances inside an Auto Scaling Group (ASG).  

It also includes a **GitHub Actions workflow** to automatically sync Ansible code to the controller server and manage secrets with AWS Secrets Manager.

---

## 🚀 Features
- **Inventory**
  - Dynamic AWS EC2 inventory plugin
  - Targets EC2 instances in the ASG provisioned by Terraform
- **Playbooks**
  - Install Docker, Python dependencies, AWS CLI
  - Authenticate to ECR
  - Pull Docker images by tag
  - Start/replace Nginx container hosting the website
- **Secrets**
  - Managed using Ansible Vault + AWS Secrets Manager
  - Vault password is securely fetched on the controller at runtime
- **CI/CD**
  - GitHub Actions pipeline syncs Ansible configs to the controller server
  - Ensures vault secrets are always encrypted and up to date

---

## ⚙️ GitHub Actions Workflow

This repo includes a GitHub Actions workflow to **sync Ansible configs to the controller** and manage vault secrets.  

### Trigger
- Runs on every push to the `main` branch.

### Steps
1. Checkout code  
2. Add SSH private key for the controller  
3. Trust the controller host key  
4. Ensure `/home/ubuntu/ansible` exists on the controller  
5. Install ASG private key on the controller for SSH access to EC2s  
6. Fetch secrets from AWS Secrets Manager and create an **encrypted vault file**  
7. Rsync only changed Ansible files to the controller  

---

## 🔐 GitHub Actions Secrets

This repo requires several **GitHub Actions repository secrets** for the CI/CD workflow to work.  
These must be configured in **Repository → Settings → Secrets and variables → Actions**.

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `ANSIBLE_SSH_PRIVATE_KEY` | Private SSH key used by GitHub Actions to connect to the Ansible controller | `-----BEGIN OPENSSH PRIVATE KEY----- ...` |
| `ANSIBLE_HOST` | Public IP or DNS of the Ansible controller | `ec2-3-91-123-45.compute-1.amazonaws.com` |
| `EC2_USER` | SSH username on the controller instance | `ubuntu` (default for Ubuntu AMIs) |
| `ASG_SSH_KEY` | Private SSH key that the controller uses to connect to EC2 instances in the ASG | `-----BEGIN OPENSSH PRIVATE KEY----- ...` |

> ✅ The workflow injects these values securely at runtime. They should never be hardcoded in code or committed to the repo.

---

### How Secrets Work in the Workflow
1. **GitHub Actions** uses `ANSIBLE_SSH_PRIVATE_KEY` to SSH into the controller.  
2. It uses `ANSIBLE_HOST` + `EC2_USER` to know where and how to connect.  
3. It copies `ASG_SSH_KEY` onto the controller so Ansible can SSH into the ASG EC2 instances.  
4. On the controller, the workflow runs:  
   - `aws secretsmanager get-secret-value` → writes decrypted values into `group_vars/all/vault.yml`  
   - Immediately encrypts that file with Ansible Vault, using `secrets_script.sh` (which itself fetches the vault password dynamically from AWS Secrets Manager).

---

## 🔐 Secrets Management

This repo does **not** keep sensitive values in plain text. Instead:

1. **GitHub Actions** workflow:
   - Creates the folder `group_vars/all` on the controller if it doesn’t exist.
   - Runs an **AWS Secrets Manager** command to fetch all Ansible secrets (e.g., `aws_account_id`, `region`, `ecr_repo`, `image_tag`, `container_name`, ports, etc.).
   - Writes those values into a file called `vault.yml` under `group_vars/all/`.

   Example JSON stored in AWS Secrets Manager (`ansible/vault_file_secrets`):

   ```json
   {
     "aws_account_id": "123456789012",
     "aws_region": "us-east-1",
     "ecr_repo": "my-dev-ecr-repo-1",
     "image_tag": "dev",
     "container_name": "myapp",
     "host_port": "80",
     "container_port": "80",
     "ansible_user": "ubuntu",
     "ansible_ssh_private_key_file": "/home/ubuntu/.ssh/asg.pem"
   }
   ```

2. **Encryption with Ansible Vault**:
   - Immediately after writing, the workflow encrypts `vault.yml` using `ansible-vault encrypt`.
   - The vault password is **not stored in the repo**. Instead, it comes from a helper script `secrets_script.sh`.

3. **Vault Password Script (`secrets_script.sh`)**:
   - This script is committed to the repo but does not contain the actual password.
   - At runtime, it executes an `aws secretsmanager get-secret-value` call to fetch the real vault passphrase from AWS Secrets Manager.
   - Ansible uses this script as `--vault-password-file` so the password is injected dynamically **only when needed**, never written to disk in plain text.

---

### Flow Diagram
```
GitHub Actions
|
v
Creates group_vars/all/ on controller
|
v
aws secretsmanager get-secret-value (all Ansible vars) ---> vault.yml (plaintext)
|
v
ansible-vault encrypt vault.yml --vault-password-file secrets_script.sh
|
v
secrets_script.sh ---> calls aws secretsmanager get-secret-value (vault pass only)
```
---

### Why this matters
- No secrets are hardcoded into the repo.
- `vault.yml` only exists encrypted on the controller.
- The vault password never lives in GitHub; it’s fetched just-in-time from AWS.
- Any team member running playbooks only needs AWS IAM access + the repo, no shared vault pass in Slack/email/etc.


## 📂 Structure
```
ansible-controller-config/ 
├── .github/workflows
│ └── ans_cicd.yaml
├── ansible
│ └── inventory
  │ └── aws_ec2.yml
│ └── playbooks
  │ └── deploy.yml
│ └── ansible.cfg
│ └── requirements.yml
│ └── secrets_script.sh

```