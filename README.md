# FlowForge Infrastructure as Code (IaC) Guide

This document is the **Single Source of Truth** for setting up and deploying the FlowForge infrastructure using Terraform, GitHub Actions, and Azure OpenID Connect (OIDC).

---

## 1. Architectural Overview & The Single Physical Environment Strategy

We use an Enterprise GitOps CI/CD model powered by GitHub Environments.

* **Dev Environment**: Provisioned from `env/dev`. Triggered on push to `Cloud-Track-dev`.
* **Prod Environment**: Provisioned from `env/prod`. Triggered on merge to `main`.
* **Modules**: Shared infrastructure components located in `modules/`.

> **COST SAVING TRICK:** Because this is a portfolio/training project, we maintain the illusion of a massive multi-environment setup, but we only pay for Prod!
> - When you push to Dev, the pipeline runs the Plan and hits the "Dev Environment Gate" in GitHub Actions.
> - **You simply never click Approve!** You review the plan to ensure it works, but you do not deploy the infrastructure.
> - You then open a PR to `main`. When merged, the Prod pipeline runs, you click Approve on the "Prod Environment Gate", and the real infrastructure is deployed.

---

## 2. Azure Pre-requisites (One-Time Setup)

Before triggering any pipelines, you must manually establish the foundational Azure resources for storing the Terraform State and authenticating GitHub.

### A. Terraform State Storage
Terraform requires a remote backend to store the state file (`.tfstate`) securely.
1. Create an Azure Resource Group (e.g., `Noel-STF`).
2. Create an Azure Storage Account inside that resource group (e.g., `noelstf98`).
3. Create a Blob Container inside the storage account (e.g., `statefile`).

*Repeat this process if you want physically separate state storage for Dev and Prod.*

### B. Azure App Registration (Service Principal)
To avoid storing passwords, we use an App Registration for identity.
1. Go to **Microsoft Entra ID** -> **App registrations** -> **New registration**.
2. Name it (e.g., `github-actions-terraform`) and register.
3. Note down the **Application (client) ID** and the **Directory (tenant) ID**.

### C. Federated Credentials (OIDC)
Tell Azure to trust GitHub Actions running from this repository.
1. Inside your App Registration, go to **Certificates & secrets** -> **Federated credentials**.
2. Click **Add credential** -> **GitHub Actions deploying Azure resources**.
3. Fill in the details:
   - **Organization**: Your GitHub username or organization (e.g., `Noel-Mathews-Org`)
   - **Repository**: Your repository name (e.g., `FlowForge`)
   - **Entity type**: `Branch`
   - **GitHub branch name**: `Cloud-Track-dev` (All deployments originate from this branch)

> **IMPORTANT:** If you ever decide to deploy Prod from a different branch (e.g., `main`), you must create a second Federated Credential specifically for that branch.

---

## 3. Azure RBAC Role Assignments (Resource Group Scoping)

The App Registration needs explicit permissions to interact with your Azure environment. Instead of giving it access to your entire subscription, we securely trap it inside specific Resource Groups.

**Prerequisite:** Manually create two Resource Groups in Azure (e.g., `Noel-RG-Dev` and `Noel-RG-Prod`). You can create these in whatever region you prefer; Terraform will still deploy the resources inside them to the region defined in `terraform.tfvars`.

1. **Role Based Access Control Administrator (or Owner)**
   - **Why?** Terraform creates role assignments between your resources (e.g., giving AKS permission to read Key Vault). It needs permission to manage access.
   - Go to your specific Resource Group (e.g., `Noel-RG-Prod`) -> **Access control (IAM)** -> **Add role assignment**.
   - Select the **Role Based Access Control Administrator** role.
   - Select **User, group, or service principal**.
   - Search for your App Registration (Tip: Paste the **Application (client) ID**) and assign the role.

2. **Contributor Role (Infrastructure Provisioning)**
   - Repeat the steps above on the exact same Resource Group, but assign the **Contributor** role so Terraform can build/modify resources inside it.

3. **Storage Blob Data Contributor (State File Access)**
   - Go to your Terraform State **Storage Account** (e.g., `noelstf98`) -> **Access control (IAM)** -> **Add role assignment**.
   - Select the **Storage Blob Data Contributor** role.
   - Search for your App Registration and assign the role.

---

## 4. GitHub Secrets Configuration

Go to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions** and add the following **Repository Secrets**:

| Secret Name | Description |
| :--- | :--- |
| `AZURE_CLIENT_ID` | The Application (client) ID from your App Registration. |
| `AZURE_TENANT_ID` | The Directory (tenant) ID of your Entra ID. |
| `AZURE_SUBSCRIPTION_ID` | Your Azure Subscription ID where infrastructure will be built. |
| `MAIL_USERNAME` | SMTP Email username for pipeline success/failure notifications. |
| `MAIL_PASSWORD` | SMTP Email password. |
| `DEVELOPMENT_TEAM_EMAIL` | The destination email address for deployment alerts. |

---

## 5. Terraform Code Configuration

Ensure your `providers.tf` files are configured to use OIDC authentication. The `backend "azurerm"` block must include `use_oidc = true`.

**Example (`terraform/env/prod/providers.tf`):**
```terraform
terraform {
  backend "azurerm" {
    resource_group_name  = "Noel-STF"
    storage_account_name = "noelstf98"
    container_name       = "statefile"
    key                  = "prod.terraform.tfstate"
    use_oidc             = true
  }
}
```
*(Ensure this is uncommented and correctly mapped in both Dev and Prod!)*

---

## 6. Deployment Workflows (GitOps)

We use a fully automated, PR-driven GitOps pipeline. 

### Trigger Rules
- **Push to `Cloud-Track-dev` branch:** Triggers the Dev Pipeline.
- **Push or Merge to `main` branch:** Triggers the Prod Pipeline.

### Provisioning Infrastructure
1. Push your changes to `Cloud-Track-dev` (or open a PR to `main`).
2. The CI job will run `terraform fmt`, `terraform validate`, and **`snyk iac test`** (to scan for cloud misconfigurations).
3. The runner executes `terraform plan` and uploads the output.
4. **The Environment Gate:** The runner hits a GitHub Environment (`dev` or `prod`) and goes to sleep.
5. You go to the GitHub Actions UI, review the plan, and click **Review deployments -> Approve**.
6. The runner wakes up and executes `terraform apply -auto-approve`.

---

## 7. Secure Secrets Injection

> **CAUTION:** Do not expose your Azure Key Vault to the public internet just to let a GitHub Action inject Application Secrets (e.g., JWT keys, OpenAI tokens).

Application Secrets should be managed locally and securely.
1. Maintain your secrets locally in `secrets.env`.
2. Ensure `secrets.env` is listed in your `.gitignore` so it is never pushed to GitHub.
3. Connect to your Azure environment securely via a **Point-to-Site VPN** or by SSH-ing into your **Jumpbox**.
4. From within the private network, run the upload script:
   ```bash
   ./upload_secrets.sh -v <your-key-vault-name>
   ```
This ensures your Key Vault remains entirely private while being securely populated.
