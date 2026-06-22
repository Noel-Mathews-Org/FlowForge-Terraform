#Setting Remote Backend - 1st Step
# Keep your own variables whenever running the script and make sure you are logged into azure cli
$RESOURCE_GROUP_NAME  = "NoelSTS-RG"
$LOCATION             = "centralindia"
$STORAGE_ACCOUNT_NAME = "noelsts0910"
$CONTAINER_NAME       = "statefile"
$CONTRIBUTOR_OBJ_ID   = "ee161602-2ab7-43b0-8509-94f4d5ebfc8f"
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "Starting Azure Backend Bootstrapping..." -ForegroundColor Cyan

try {
    Write-Host "Creating Azure Resource Group: $RESOURCE_GROUP_NAME"
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION --output none

  
    Write-Host "Creating Azure Storage Account: $STORAGE_ACCOUNT_NAME (Zone Redundant)"
    az storage account create `
        --resource-group $RESOURCE_GROUP_NAME `
        --name $STORAGE_ACCOUNT_NAME `
        --sku Standard_ZRS `
        --encryption-services blob `
        --output none

  
    Write-Host "Creating Blob Container: $CONTAINER_NAME"
    $ACCOUNT_KEY = $(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)
    
    if (-not $ACCOUNT_KEY) {
        throw "Failed to retrieve storage account key."
    }

    az storage container create `
        --name $CONTAINER_NAME `
        --account-name $STORAGE_ACCOUNT_NAME `
        --account-key $ACCOUNT_KEY `
        --output none


    Write-Host "Assigning Storage Blob Data Contributor role to Object ID: $CONTRIBUTOR_OBJ_ID"
    $STORAGE_ACCOUNT_ID = $(az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME --query id -o tsv)
    
    if (-not $STORAGE_ACCOUNT_ID) {
        throw "Failed to retrieve storage account ID for role assignment."
    }

    az role assignment create `
        --role "Storage Blob Data Contributor" `
        --assignee-object-id $CONTRIBUTOR_OBJ_ID `
        --scope $STORAGE_ACCOUNT_ID `
        --output none

    Write-Host "Azure Backend successfully created and role assigned!" -ForegroundColor Green
    Write-Host "----------------------------------------"
    Write-Host "To initialize Terraform for Azure, run:"
    Write-Host "terraform init -backend-config=`"resource_group_name=$RESOURCE_GROUP_NAME`" -backend-config=`"storage_account_name=$STORAGE_ACCOUNT_NAME`" -backend-config=`"container_name=$CONTAINER_NAME`" -backend-config=`"key=azure-prod.terraform.tfstate`""
    Write-Host ""
} catch {
    Write-Host "An error occurred during backend bootstrapping:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
