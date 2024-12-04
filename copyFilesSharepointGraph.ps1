# Define the necessary variables
$clientId = "CLIENT_ID"         # ClientID from EntraID App Registration 
$clientSecret = "SECRET"        # Secret from EntraID App Registration
$tenantId = "TENANT_ID"         # TenantID from EntraID App Registration 
$siteId = "TENANT_NAME.sharepoint.com,GUID,GUID"        # SiteID from Sharepoint
#$siteName = "BackupsHTD"
$localFolderPath = "D:\SourcePath"
$sharePointFolderPath = "Shared Documents"

# Connect to Microsoft Graph
$secureClientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$clientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $secureClientSecret
Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $clientSecretCredential

#$site = Get-MgSite -Search $siteName -Debug
$site = get-mgsite -SiteId $siteId
# Get the drive
$drive = Get-MgSiteDrive -SiteId $site.Id
$driveId = $drive.Id

# Function to get all files and subfolders
function Get-FilesAndSubfolders($path) {
    $files = @()
    $subfolders = @()
    Get-ChildItem -Path $path -Recurse | ForEach-Object {
        if ($_.PSIsContainer) {
            $subfolders += $_.FullName
        } else {
            $files += $_.FullName
        }
    }
    return $files, $subfolders
}

# Get files and subfolders
$files, $subfolders = Get-FilesAndSubfolders $localFolderPath

# Create subfolders in SharePoint
foreach ($subfolder in $subfolders) {
    $relativePath = $subfolder.Substring($localFolderPath.Length).TrimStart('\')
    $folderPath = "$sharePointFolderPath/$($relativePath.Replace('\', '/'))"
    $params = @{
        name = $relativePath
        folder = @{
            childCount = 0
        }
        "@microsoft.graph.conflictBehavior" = "replace"
    }
    New-MgDriveItem -DriveId $driveId -BodyParameter $params
}

# Upload files
foreach ($file in $files) {
    $relativePath = $file.Substring($localFolderPath.Length).TrimStart('\')
    $uploadPath = "$sharePointFolderPath/$($relativePath.Replace('\', '/'))"
    $fileName = Split-Path $file -Leaf

    $params = @{
        name = $fileName
        file = @{
            mimeType = "application/octet-stream"
        }
        "@microsoft.graph.conflictBehavior" = "replace"
    }
    $driveItem = New-MgDriveItem -DriveId $driveId -BodyParameter $params
    Set-MgDriveItemContent -DriveId $driveId -DriveItemId $driveItem.Id -InFile $file

    Write-Host "Uploaded: $uploadPath"
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph