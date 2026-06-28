# FlowForge Infrastructure as Code (IaC) Guide

![IaC Cloud Architecture](Cloud%20white.png)

This document is the **Single Source of Truth** for setting up, deploying, and managing the FlowForge infrastructure using Terraform, GitHub Actions, and Azure Active Directory (Entra ID) Workload Identity.

---

## 1. Architectural Overview & Bootstrapping Strategy

We leverage an enterprise-grade Hub-and-Spoke networking architecture and OIDC-based authentication to host the FlowForge application. To optimize costs and facilitate testing, we utilize a unified environment management strategy.

### Bootstrapping & Environment Parity (`og-prod` vs `prod`):
To enable clean teardowns and rapid environment recreation with minimal configuration overhead, our code differentiates between **persistent bootstrapping** and **ephemeral cluster infrastructure**:
* **`env/og-prod` (Original Production Bootstrap)**: Used for the initial setup to construct the highly persistent components of our platform. Specifically, it builds the **Azure Container Registry (ACR)** and the **User Assigned Managed Identities** (e.g. `mi-github-actions-prod`, `mi-flowforge-app-*`, etc.) that are bound to our GitHub repository.
* **`env/prod` (Production Cluster / Ephemeral Lifecycle)**: Configured to treat identities and registries as external data sources (`data` blocks). This allows us to securely run `terraform destroy` and `terraform apply` on all virtual networks, firewalls, gateways, VPNs, databases, and AKS clusters without deleting our container images, breaking federated OIDC credentials, or mutating critical client IDs in Entra ID.

---

## 2. Azure Pre-requisites & One-Time Bootstrapping

Before triggering any pipelines, you must manually establish the remote backend storage and configure authentication permissions.

### Step 1: Remote Backend Storage using the Bootstrap Script
Terraform requires a remote backend to store the state file (`.tfstate`) securely.
1. Log in to your Azure account using the Azure CLI (`az login`).
2. Navigate to the `scripts/` folder.
3. Open and run the `bootstrap_backend.ps1` script:
   ```powershell
   ./bootstrap_backend.ps1
   ```
   * **What this does**:
     - Creates the dedicated backend Resource Group (e.g., `NoelSTS-RG`).
     - Provisions a Zone Redundant Storage Account (e.g., `noelsts0910`) and a Blob Container (`statefile`).
     - Grants the **Storage Blob Data Contributor** role to the App Registration (Service Principal) Object ID (defined by `$CONTRIBUTOR_OBJ_ID`), allowing Terraform to read and write state files.

### Step 2: App Registration & Federated Credentials (OIDC)
The Terraform IaC pipelines authenticate securely to Azure using an App Registration (Service Principal) instead of client secrets.
1. Create an **App Registration** in Microsoft Entra ID (e.g., `github-actions-terraform`).
2. Go to **Certificates & secrets** -> **Federated credentials**.
3. Create federated credentials mapping to the **4 GitHub environments** defined in the workflows:
   * **`dev-create`**: Mapped to the `dev` deployment environment.
   * **`dev-destroy`**: Mapped to the `dev-destroy` manual execution environment.
   * **`prod-create`**: Mapped to the `prod` deployment environment.
   * **`prod-destroy`**: Mapped to the `prod-destroy` manual execution environment.

### Step 3: Setup Target Resource Group & Permissions
1. Create the target deployment Resource Group in Azure (e.g., `Noel-RG`).
2. Go to **Access control (IAM)** -> **Add role assignment** inside this target Resource Group.
3. Grant the App Registration Object ID the following roles:
   * **Contributor**: To allow the creation and deletion of all virtual networks, databases, VM hosts, and AKS clusters.
   * **Role Based Access Control Administrator**: To allow Terraform to establish role assignments between the provisioned resources (e.g., giving the AKS Kubelet pull access on ACR).

---

## 3. Infrastructure Resources Built by Terraform

Here is an explanation of every resource created across the Terraform modules:

### A. Network Architecture (Hub-and-Spoke)
* **Hub Virtual Network (`modules/hub_network`)**: The network core. It hosts the management plane.
  * **Management Subnet**: Hosts the Jumpbox VM.
  * **Bastion Subnet**: Allows secure Azure Bastion access if needed.
* **Spoke Virtual Network (`modules/spoke_network`)**: The application network plane. Subdivided into dedicated subnets:
  * **AKS Subnet**: Dedicated subnet for the AKS node pools.
  * **Application Gateway Subnet**: Dedicated ingress subnet for Application Gateway.
  * **Private Endpoints Subnet (`pe_subnet`)**: Subnet housing private link interfaces.
  * **Database Subnet (`db_subnet`)**: Hosts database private links.
* **Private DNS Zones**: Establishes private name resolution within the Spoke VNet for backend services:
  * `privatelink.vaultcore.azure.net` (Key Vault)
  * `privatelink.blob.core.windows.net` (Storage Accounts)
  * `privatelink.postgres.database.azure.com` (PostgreSQL Server)
  * `privatelink.redis.cache.windows.net` (Redis Cache)
  * `privatelink.eastus2.azmk8s.io` (AKS Private Cluster Endpoint)

### B. Security & Gateways
* **Azure Firewall (`modules/firewall`)**: The central egress gateway. Uses User-Defined Routing (UDR) on the AKS subnet to inspect and filter all outbound traffic to the internet, enforcing FQDN-based white-lists (e.g. allowing Microsoft Login and public package registries while blocking untrusted destinations).
* **VPN Gateway (`modules/vpn_gateway`)**: A Point-to-Site Virtual Network Gateway in the Hub network. Utilizes Microsoft Entra ID authentication, enabling administrators to securely tunnel into the internal virtual networks directly.
* **Application Gateway (`modules/app_gateway`)**: Operates as the Ingress Controller (AGIC) for the AKS cluster, terminating public TLS certificates and forwarding traffic to frontend and gateway pods.
* **Jumpbox VM (`modules/jumpbox`)**: A Windows Server virtual machine placed in the Hub management subnet. Acts as an internal operations base to configure databases or run manual scripts.

### C. Compute & Applications
* **Azure Kubernetes Service (`modules/aks`)**: The core compute cluster. Runs on two node pools: a system node pool for cluster management tools, and a user node pool targeting `agentpool: node1` for the FlowForge workloads. Configured with OIDC Issuer and Workload Identity enabled.
* **Azure Database for PostgreSQL Flexible Server (`modules/databases`)**: Houses the application storage. Protected via Private Endpoint.
* **Azure Cache for Redis (`modules/databases`)**: High-performance cache for service rate-limiting and task execution, bound to a private link.
* **Key Vault (`modules/key_vault`)**: Houses application variables and connection tokens (JWT secret, Redis keys, DB passwords).
* **Storage Account (`modules/storage`)**: Blob storage container used to host application report files and document archives.
* **Azure AI Foundry / Cognitive Services (`modules/ai_foundry`)**: Deploys an Azure OpenAI cognitive account and provisions the `summary-agent` model, utilized by the `analysis-service` to process telemetry summaries.

---

## 4. Network Communication Flow

```text
[External Users]           [Operators / Admins]
      │                            │
      ▼ (HTTPS)                    ▼ (Entra ID Auth)
[Application Gateway]        [VPN Gateway]
      │                            │
      ▼ (Internal Routes)          ▼ (Secure Tunnel)
  [AKS Subnet] ◄─────────────► [Hub VNet (Jumpbox)]
      │
      ├── (Private Link / PE Subnet) ──► [Postgres, Redis, Storage, Key Vault]
      │
      └── (UDR Routing) ───────────────► [Azure Firewall] ──► [Public Internet]
```

1. **Ingress Path**: External users resolve domains via DNS to the public IP of the Azure Application Gateway. The Application Gateway terminates SSL/TLS and proxies HTTP requests to the private IPs of the AKS pods in the Spoke VNet.
2. **Backend Communication**: Services running in AKS communicate with Postgres, Redis, Azure Storage, and Azure Key Vault via **Private Endpoints** situated in the `pe_subnet`. All calls stay on Azure's private fiber backbone; traffic never touches the public internet.
3. **Egress Path**: AKS pods route internet traffic through a Route Table (UDR) pointing to the private IP of the **Azure Firewall**. The firewall filters traffic based on application and network rules before forwarding it to the internet.
4. **Management Path**: Developers connect using Azure VPN Client. Once connected, they can directly communicate with private IP endpoints or RDP into the Jumpbox VM.

---

## 5. Managed Identities Reference

To completely eliminate static credentials (passwords/keys) in runtime environments, we use Microsoft Entra ID Workload Identity. The following User-Assigned Managed Identities are provisioned:

1. **`mi-github-actions-prod`**: Used by the application code CI/CD pipeline (FlowForge code repository) to authenticate and push built Docker images to the Azure Container Registry (ACR).
2. **`mi-flowforge-app-<env>`**: Federated to microservices running in AKS (`gateway`, `auth-service`, `project-service`, `task-service`, `notification-worker`). Used to retrieve credentials and access Azure resources securely.
3. **`mi-arc-runner-<suffix>`**: Federated to the self-hosted Actions Runner Controller (ARC) runner (`arc-runner-sa`). Used by runners inside the cluster to sync repository secrets directly into Key Vault.
4. **`mi-flowforge-otel-<suffix>`**: Federated to the OpenTelemetry collector pod (`otel-collector-sa`). Used to publish application telemetry (traces, metrics, logs) to Azure Application Insights.
5. **`mi-ai-<env>-<suffix>`**: Federated to the `analysis-service` pod. Used to invoke LLM APIs, fetch keys, and save AI-generated reports.
6. **`mi-<aks_cluster_name>-cp`**: Control-plane identity for AKS nodes. Used for managing routing configurations, attaching VNICs, and provisioning resources.

---

## 6. RBAC Permission Matrix

The following RBAC permissions are assigned dynamically to authorize our automated pipelines and services:

### IaC Pipeline & Developer Access
* **App Registration (Service Principal)**:
  * `Storage Blob Data Contributor` (on backend storage account): Authorizes Terraform to read/write state files (`.tfstate`).
  * `Contributor` (on deployment resource group): Permits building/deleting all infrastructure resources.
  * `Role Based Access Control Administrator` (on deployment resource group): Permits assigning RBAC permissions between resources during provisioning.
* **DevOps Group Object ID**:
  * `Azure Kubernetes Service RBAC Cluster Admin` (on AKS): Grants full cluster administrator permissions.
  * `Log Analytics Reader` (on Log Analytics Workspace): Grants permission to read logs, audits, and performance metrics.
* **DevTest Group Object ID**:
  * `Azure Kubernetes Service RBAC Reader` (on `flowforge-dev` namespace scope): Grants read-only visibility into the dev testing namespace.

### Container & Network Automation
* **`mi-github-actions-prod`**:
  * `AcrPush` (on ACR): Authorizes the app pipeline to upload built images.
* **AKS Control Plane Identity (`mi-<aks_cluster_name>-cp`)**:
  * `Private DNS Zone Contributor` (on Private DNS Zone): Allows AKS to write dynamic DNS records (critical for routing P2S VPN users to the private API server).
  * `Network Contributor` (on AKS subnet): Authorizes nodes to associate virtual network interfaces.
* **AGIC (Application Gateway Ingress Controller) Identity**:
  * `Contributor` (on Application Gateway): Permits AGIC to configure listeners, routing rules, and backends.
  * `Reader` (on Resource Group): Permits AGIC to query network components.
  * `Network Contributor` (on Spoke VNet): Allows configuration of ingress routing tables.

### Application Pod Run-times
* **`mi-flowforge-app-<env>`**:
  * `Key Vault Secrets User` (on Key Vault): Authorizes microservices to query variables and passwords.
  * `Storage Blob Data Contributor` (on Storage Account): Authorizes services to write application report blobs.
* **`mi-arc-runner-<suffix>`**:
  * `Key Vault Secrets Officer` (on Key Vault): Authorizes the self-hosted ARC runner to write, delete, and manage secrets.
* **`mi-flowforge-otel-<suffix>`**:
  * `Monitoring Metrics Publisher` (on Resource Group): Permits OpenTelemetry to publish telemetry into Application Insights.
* **`mi-ai-<env>-<suffix>`**:
  * `Cognitive Services OpenAI User` (on AI Cognitive Account): Authorizes the analysis engine to run model inferences.
  * `Key Vault Secrets User` (on Key Vault): Permits retrieval of keys.
  * `Storage Blob Data Contributor` (on Storage Account): Permits archiving prompts and analytics data.

---

## 7. GitOps Pipelines & Security Design

We use automated, security-gated GitHub Actions workflows:

### A. Terraform GitOps Pipeline (`terraform-gitops.yml`)
* **Trigger**: Automatic on pushes to `Cloud-Track-dev` (targetting the `dev` state) or merges to `main` (targetting the `prod` state).
* **CI Phase**:
  1. Lints code using `terraform fmt`.
  2. Logins securely to Azure via OIDC (OIDC handles exchange of GitHub JWT tokens for short-lived Azure CLI tokens).
  3. Checks out the code, runs `terraform init`, `terraform validate`, and generates a `tfplan`.
  4. Runs **Checkov Security Scan** to ensure our networks, subnets, and databases conform to security best practices.
  5. Runs **Infracost** to estimate monthly cloud cost adjustments.
  6. Sends a formatted **Approval Notification Email** containing the security pass rate and the Infracost monthly budget difference to administrators.
* **CD Phase (Apply Gate)**:
  * Targets a GitHub Environment (`dev-create` or `prod-create`).
  * **Environment Protection Rule**: Requires manual review and approval by an administrator before the apply job is unlocked.
  * Once approved, the runner executes `terraform apply -auto-approve tfplan`.

### B. Terraform Destroy Pipeline (`terraform-destroy.yml`)
* **Trigger**: Manual workflow dispatch (`workflow_dispatch`).
* **Double-Safety Gating**:
  1. Requires the operator to type the target environment name as an input. The pipeline aborts if the input text does not match.
  2. Executes `terraform plan -destroy` and saves the plan.
  3. Hits the environment destroy approval gate (`dev-destroy` or `prod-destroy`).
  4. Once approved, it executes `terraform apply` on the destroy plan.

### C. Key Vault Secret Sync Pipeline (`update-keyvault-secrets.yml`)
* **Trigger**: Manual workflow dispatch.
* **Execution Environment**: Runs on our **self-hosted ARC Runner** (`runs-on: self-hosted`) inside the private AKS cluster.
* **Secret Sync Action**:
  1. The runner authenticates to Azure OIDC via the `mi-arc-runner` Workload Identity.
  2. Fetches environment variables securely from repository secrets (e.g. `SMTP_PASSWORD`, `JWT_SECRET`, `REDIS_URL`, etc.).
  3. Inserts or updates the secrets inside the private Key Vault.
  4. **Security Cleanup**: Automatically scans all previous versions of each secret in Key Vault and disables them, guaranteeing that only the newest version remains active.

---

## 8. Database Entra ID Permissions Bootstrapping (`db-permission/`)

Since our application services authenticate to the PostgreSQL flexible database using Entra ID passwordless Workload Identity, the database must be configured to recognize the managed identity principals. This configuration is located in the `db-permission/` folder.

### Bootstrapping Flow:
1. **Fetch Entra ID Access Token**:
   The admin runs `db-permission/run-setup.ps1` locally. This script uses the Azure CLI to request an OAuth 2.0 token specifically scoped for PostgreSQL Flexible Servers (`oss-rdbms` resource type):
   ```powershell
   $token = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
   ```
2. **Compile Manifests**:
   The script dynamically replaces the `__TOKEN__` placeholder in `db-job-robust.yaml` with the retrieved access token, saving the result into `db-job-applied.yaml`.
3. **Execute Kubernetes Setup Job**:
   It applies the compiled manifest to the cluster. This triggers a batch Job (`db-setup-job-v2`) inside Kubernetes that runs a standard `postgres:15-alpine` container:
   - Authenticates to the PostgreSQL server using Microsoft Entra ID (the retrieved `$token` is passed as the connection password).
   - Executes the SQL statements inside the ConfigMap `db-setup-sql` (copied from `db-job-robust.yaml`).
4. **SQL Permissions Setup**:
   The SQL execution performs the following steps:
   - Connects to the standard `postgres` database and checks if the User-Assigned Managed Identities exist. If not, it registers them using the `pgaadauth_create_principal` extension function:
     - `mi-flowforge-app-dev` (Application dev runtime)
     - `mi-ai-dev-m9mp04` (AI analysis dev service)
     - `mi-flowforge-app-prod` (Application prod runtime)
     - `mi-ai-prod-m9mp04` (AI analysis prod service)
   - Connects to the `flowforge-dev` and `flowforge-prod` databases and grants role permissions:
     - `CONNECT` to databases.
     - `USAGE` and `ALL` on the `public` schema.
     - `GRANT ALL ON ALL TABLES` and `GRANT ALL ON ALL SEQUENCES`.
     - Configures `ALTER DEFAULT PRIVILEGES` so any tables created in the future automatically inherit permissions for the corresponding managed identities.

---

## 9. GitHub Secrets Configuration

To run the GitOps workflows and sync the application credentials into Azure Key Vault, configure the following secrets in GitHub. You can scope these globally (Repository Secrets) or restrict them to environments (`dev`, `prod`, `dev-destroy`, `prod-destroy`).

### A. Secrets Required for Terraform Provisioning (IaC & Destroy Pipelines)
These secrets authenticate Terraform to your subscription and configure VM/DB administrator credentials during infrastructure generation:

* **`AZURE_CLIENT_ID`**: The Application (Client) ID of your Entra ID App Registration.
* **`AZURE_TENANT_ID`**: The Directory (Tenant) ID of your Entra ID.
* **`AZURE_SUBSCRIPTION_ID`**: Your Azure Subscription ID where resources will be built.
* **`POSTGRES_ADMIN_USERNAME`**: Admin username for the PostgreSQL Flexible Server database.
* **`POSTGRES_ADMIN_PASSWORD`**: Admin password for the PostgreSQL Flexible Server database.
* **`JUMPBOX_ADMIN_PASSWORD`**: Local Administrator password for the Jumpbox VM.
* **`INFRACOST_API_KEY`**: API token for Infracost to calculate budget modifications on pull requests.
* **`MAIL_USERNAME`**: SMTP email address used to send status and manual-approval notifications.
* **`MAIL_PASSWORD`**: SMTP email password (or application-specific password).
* **`DEVELOPMENT_TEAM_EMAIL`**: The recipient email address for deployment alerts and approval actions.

### B. Secrets Required to Update Key Vault (`update-keyvault-secrets.yml`)
These secrets represent the application credentials. They must be configured within the **`dev`** and **`prod`** GitHub Environments. The self-hosted runner reads these values and syncs them into the respective Key Vault (`kvlt-dev-*` or `kvlt-prod-*`):

| GitHub Secret Name | Mapped Key Vault Secret Name | Purpose |
| :--- | :--- | :--- |
| `REDIS_URL` | `redis-url` | Connection string for the Azure Cache for Redis instance. |
| `JWT_SECRET` | `jwt-secret` | Encryption key used for signing application tokens. |
| `INTERNAL_API_KEY` | `internal-api-key` | Secret key for inter-service microservice authentication. |
| `ENTRA_TENANT_ID` | `entra-tenant-id` | Tenant ID for Microsoft Entra ID user authentication. |
| `ENTRA_CLIENT_ID` | `entra-client-id` | Client ID of the App Registration used for user authentication. |
| `ENTRA_CLIENT_SECRET` | `entra-client-secret` | Secret credential for user authentication App Registration. |
| `AZURE_FOUNDRY_KEY` | `azure-foundry-key` | API Key for calling the Azure AI Foundry OpenAI models. |
| `AZURE_FOUNDRY_ENDPOINT`| `azure-foundry-endpoint` | Endpoint URI of the Azure AI Foundry service. |
| `SMTP_USERNAME` | `smtp-username` | Outbound mail SMTP server username for the application. |
| `SMTP_PASSWORD` | `smtp-password` | Outbound mail SMTP server password for the application. |
| `ENTRA_GROUP_PLATFORM_ADMIN` | `entra-group-platform-admin` | Object ID of the Entra Group for Platform Admins. |
| `ENTRA_GROUP_ORG_OWNER` | `entra-group-org-owner` | Object ID of the Entra Group for Organization Owners. |
| `ENTRA_GROUP_MANAGER` | `entra-group-manager` | Object ID of the Entra Group for Managers. |
| `ENTRA_GROUP_MEMBER` | `entra-group-member` | Object ID of the Entra Group for General Members. |
