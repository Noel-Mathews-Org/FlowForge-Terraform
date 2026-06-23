# Infrastructure as Code (IaC) & Key Vault Pipelines

This document provides a comprehensive overview of the GitHub Actions pipelines implemented in the `FlowForge-Terraform` repository. These pipelines form the core of our automated GitOps deployment strategy and secret management.

---

## 1. Terraform GitOps Pipeline (`terraform-gitops.yml`)

This pipeline automatically provisions, tests, and deploys Azure infrastructure based on changes made to the Terraform code.

### Trigger Mechanism
* **Push**: Automatically triggers when code is pushed to `main` (Production) or `Cloud-Track-dev` (Development).
* **Pull Request**: Automatically triggers for pull requests targeting the `main` branch.

### Workflow Stages
1. **Determine Environment**: Dynamically sets the environment to `prod` or `dev` based on the target branch.
2. **Terraform CI (Plan & Scan)**:
   * Validates and formats the Terraform code.
   * Generates a speculative execution plan (`terraform plan`).
   * Runs **Checkov** to statically analyze the plan for security misconfigurations.
   * Runs **Infracost** to estimate the cloud bill impact of the proposed changes.
3. **Notify Approval Required**: If triggered by a push, it sends an email to the DevOps/Development team containing the security results and cost estimate, awaiting human review.
4. **Terraform CD (Apply)**: Automatically executes `terraform apply` to provision the resources if it is a direct push (or after PR merge).
5. **Notify Team**: Sends a final success/failure email notification with execution logs.

### Required GitHub Secrets & Variables
To successfully run this pipeline, the following secrets must be configured in your GitHub repository/environments:

**Cloud Authentication (OIDC Federation):**
* `AZURE_CLIENT_ID`: Client ID of the Managed Identity/App Registration.
* `AZURE_TENANT_ID`: Azure Active Directory Tenant ID.
* `AZURE_SUBSCRIPTION_ID`: Target Azure Subscription ID.

**Infrastructure Passwords:**
* `POSTGRES_ADMIN_USERNAME`: Admin username for Azure PostgreSQL.
* `POSTGRES_ADMIN_PASSWORD`: Admin password for Azure PostgreSQL.
* `JUMPBOX_ADMIN_PASSWORD`: Admin password for the Bastion/Jumpbox VMs.

**Third-Party Integrations:**
* `INFRACOST_API_KEY`: API key for Infracost cloud cost estimation.
* `MAIL_USERNAME` / `MAIL_PASSWORD`: Credentials for the SMTP server (e.g., Gmail) to send notifications.
* `DEVELOPMENT_TEAM_EMAIL`: The recipient email address for deployment notifications.

---

## 2. Key Vault Secrets Synchronization (`update-keyvault-secrets.yml`)

Because sensitive application secrets should never be hardcoded in Terraform or stored in plaintext, this pipeline synchronizes secrets directly from GitHub Actions securely into Azure Key Vault. 

This job runs on our **Self-Hosted Kubernetes ARC Runner**, meaning the traffic and authentication never leave our secure virtual network.

### Trigger Mechanism
* **Manual Trigger (`workflow_dispatch`)**: This pipeline is triggered manually via the GitHub Actions UI.
* When triggered, it prompts the user to select the target environment (`dev` or `prod`).

### How it Works
1. **Self-Hosted Execution**: The pipeline is picked up by the `terraform-runner` pod running inside the AKS cluster.
2. **Workload Identity Authentication**: It authenticates to Azure **natively** using AKS Workload Identity (`az login --federated-token`). This means it utilizes the highly secure, short-lived OIDC token injected directly into the runner pod by Kubernetes, completely eliminating the need for hardcoded credentials.
3. **Secret Synchronization**: It iterates through a predefined list of secrets stored in GitHub Environments and pushes them to Azure Key Vault.
4. **Version Control**: If a secret changes, it uploads the new version and explicitly **disables** all older versions of that secret in Key Vault to ensure no stale secrets remain active.
5. **Notification**: Sends a success/failure status email.

### Required Configuration

**Repository Variables:**
* `KEYVAULT_NAME`: Must be configured in the GitHub Environment variables (e.g., `kvlt-dev-m9mp04`).

**Required GitHub Secrets:**
The following secrets must be populated in the target GitHub Environment (`dev` or `prod`). The pipeline will map these to specific Key Vault secret names:

* `DATABASE_URL` -> Key Vault: `database-url`
* `REDIS_URL` -> Key Vault: `redis-url`
* `JWT_SECRET` -> Key Vault: `jwt-secret`
* `INTERNAL_API_KEY` -> Key Vault: `internal-api-key`
* `ENTRA_TENANT_ID` -> Key Vault: `entra-tenant-id`
* `ENTRA_CLIENT_ID` -> Key Vault: `entra-client-id`
* `ENTRA_CLIENT_SECRET` -> Key Vault: `entra-client-secret`
* `AZURE_FOUNDRY_KEY` -> Key Vault: `azure-foundry-key`
* `AZURE_FOUNDRY_ENDPOINT` -> Key Vault: `azure-foundry-endpoint`
* `SMTP_USERNAME` -> Key Vault: `smtp-username`
* `SMTP_PASSWORD` -> Key Vault: `smtp-password`
* `ENTRA_GROUP_PLATFORM_ADMIN` -> Key Vault: `entra-group-platform-admin`
* `ENTRA_GROUP_ORG_OWNER` -> Key Vault: `entra-group-org-owner`
* `ENTRA_GROUP_MANAGER` -> Key Vault: `entra-group-manager`
* `ENTRA_GROUP_MEMBER` -> Key Vault: `entra-group-member`

*(It also uses `MAIL_USERNAME`, `MAIL_PASSWORD`, and `DEVELOPMENT_TEAM_EMAIL` to send the final notification email).*

### Setup Instructions
1. Ensure the **AKS cluster** and **Azure Key Vault** have been provisioned by the `terraform-gitops.yml` pipeline.
2. Navigate to **Settings > Environments** in the GitHub repository.
3. Create/Select the environment (e.g., `dev`).
4. Add the `KEYVAULT_NAME` as an **Environment Variable**.
5. Add all the required application values as **Environment Secrets**.
6. Go to the **Actions** tab, select **Update Key Vault Secrets**, click **Run workflow**, and select your target environment.
