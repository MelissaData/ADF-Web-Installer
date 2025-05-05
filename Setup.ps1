# =======================================
# Start Powershell As Administrator
# =======================================
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting PowerShell as Administrator..."
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# =======================================
# Configuration - MAKE MODIFICATION HERE
# =======================================

# Blob storage information
$storageAccount     = "<your_storage_account_name>"
$containerName      = "<your_container_name>"

# SAS token for accessing the container (include the leading '?')
$sasToken           = "<your_blob_container_SAS>" # This should look like "?sp=...&sig=..."

# User Product License
$productLicense     = "<your_melissa_license_key>"


# ======================================================= #
# ======================================================= #
# PLEASE DO NOT MAKE ANY MODIFICATION FROM THIS PART DOWN #
# ======================================================= #
# ======================================================= #

# =======================================
# Variable - Timestamp for Logging
# =======================================
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$timestampFileName = $timestamp -replace "[: ]", "_"

# =======================================
# Variable - Web Service Installer Name
# =======================================
$webInstallerName = "ADF-DQC-Web"

# =======================================
# Local Paths
# =======================================
$setupDir                       = "C:\SetupFiles"
$logDir                         = "C:\SetupLogs"
$dotnetFramework35Dir           = "$setupDir\dotnetFramework35\"

$customSetupLogFileName         = "$timestampFileName-custom_setup.log"
$customSetupLogFile             = "$logDir\$customSetupLogFileName"

$installerLogName               = "$timestampFileName-$webInstallerName-Install.log"
$installerLogPath               = "$logDir\$installerLogName"
$tempInstallerLog               = "$logDir\temp-$webInstallerName-Install.log"


$dqcWebLocalPath                = Join-Path $setupDir "$webInstallerName.exe"
$dotnetFramework35CabLocalPath  = Join-Path $dotnetFramework35Dir "microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~amd64~~.cab"

$smartMoverExportsDir           = "C:\SmartMoverExports"

# =======================================
# Create Local Directories
# =======================================
New-Item -ItemType Directory -Force -Path $setupDir                 | Out-Null
New-Item -ItemType Directory -Force -Path $logDir                   | Out-Null
New-Item -ItemType Directory -Force -Path $dotnetFramework35Dir     | Out-Null
New-Item -ItemType Directory -Force -Path $smartMoverExportsDir     | Out-Null

# =======================================
# Blob Paths
# =======================================

# Download from Blob
$dqcWebUrl                          = "https://$storageAccount.blob.core.windows.net/$containerName/melissa-web-installer/$webInstallerName.exe$sasToken"
$dotnetFramework35Url               = "https://$storageAccount.blob.core.windows.net/$containerName/dotnet-framework-35/microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~amd64~~.cab$sasToken"

# Upload to Blob
$customSetupLogsUploadUrl           = "https://$storageAccount.blob.core.windows.net/$containerName/custom-setup-logs/$customSetupLogFileName$sasToken"
$installerLogsUploadUrl             = "https://$storageAccount.blob.core.windows.net/$containerName/installer-logs/$installerLogName$sasToken"

# ======================================================
# Logging Function with Immediate Upload (for main log)
# ======================================================
Function Write-Log {
    param ([string]$Message)
    $logTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$logTime - $Message"
    $logEntry | Out-File -Append -FilePath $customSetupLogFile

    # Immediately upload the main log file to Blob Storage
    try {
        
        Invoke-RestMethod -Uri $customSetupLogsUploadUrl -Method Put -InFile $customSetupLogFile -ContentType "text/plain" -Headers @{ "x-ms-blob-type" = "BlockBlob" }
    }
    catch {
        Write-Host "Failed to upload main log file: $($_.Exception.Message)" -ForegroundColor Red
        Exit 1
    }
}

# ==========================================================
# Helper function to upload a log file via a temporary copy
# ==========================================================
Function Upload-Installer-LogFile {
    try {
        # Copy the file to a temporary location so it's not locked by the installer.
        Copy-Item -Path $installerLogPath -Destination $tempInstallerLog -ErrorAction Stop
        Invoke-RestMethod -Uri $installerLogsUploadUrl -Method Put -InFile $tempInstallerLog -ContentType "text/plain" -Headers @{ "x-ms-blob-type" = "BlockBlob" }
        Remove-Item $tempInstallerLog -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Log "Failed to upload installer log from temporary file: $($_.Exception.Message)"
        return $false
        Exit 1
    }
}

# =======================================
# Main Execution Block
# =======================================
try {

    # -------------------------------------------------
    # Step 1: Ensure .NET Framework 3.5 is installed 
    # -------------------------------------------------

    Try {
        if ((Get-WindowsFeature -Name Net-Framework-Core).Installed)
        {
            Write-Log ".NET framework 3.5 has already been installed."
        }
        else
        {
            Write-Log ".NET Framework 3.5 is not enabled. Attempting to install..."

            try {
                Write-Log "Downloading microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~amd64~~.cab from $dotnetFramework35Url"
    
                Start-BitsTransfer -Source $dotnetFramework35Url -Destination $dotnetFramework35CabLocalPath
                Write-Log ".NET Framework 3.5 CAB downloaded successfully to $dotnetFramework35CabLocalPath"
            }

            catch {
                Write-Log "Failed to download .NET framework 3.5 - $_"
                Exit 1
            }

            if ((Install-WindowsFeature -Name Net-Framework-Core -Source $dotnetFramework35Dir -LogPath %CUSTOM_SETUP_SCRIPT_LOG_DIR%\install.log).Success)
            {
                Write-Log ".NET framework 3.5 has been installed successfully"
            }
            else
            {
                throw "Failed to install .NET framework 3.5"
                Write-Log "Failed to install .NET framework 3.5 - $_"
                Exit 1
            }
        }
    }
    Catch {
        Write-Log "ERROR: Something went wrong while checking .NET framework 3.5 status - $_"
        Exit 1
    }

    # -------------------------------------------------
    # Step 2: Download Web Service Installer from Blob
    # -------------------------------------------------
    try {
        Write-Log "Downloading $webInstallerName.exe from Blob: $dqcWebUrl"

        Start-BitsTransfer -Source $dqcWebUrl -Destination $dqcWebLocalPath -ErrorAction Stop

        if (-Not (Test-Path $dqcWebLocalPath)) {
            throw "Download failed: $dqcWebLocalPath not found after transfer."
        }

        Write-Log "$webInstallerName.exe downloaded successfully to $dqcWebLocalPath"
    }
    catch {
        Write-Log "ERROR: Failed to download $webInstallerName.exe - $($_.Exception.Message)"
        Exit 1
    }


    # -------------------------------------------------
    # Step 3: Install Web Service Components Silently
    # -------------------------------------------------
    Write-Log "Installing $webInstallerName.exe in silent mode..."
    
    
    # Start the installer process without waiting so installer logs can be uploaded to Blob
    $global:InstallerProcess = Start-Process -FilePath $dqcWebLocalPath -ArgumentList "/VERYSILENT", "/NORESTART", "/ForceSSIS2017x64", "/LOG=$installerLogPath", "-License $productLicense", "/NoPopUp" -PassThru

    # Wait until the installer log file is created
    while (-not (Test-Path $installerLogPath)) {
        Start-Sleep -Seconds 1
    }
    $prevLineCount = (Get-Content $installerLogPath | Measure-Object -Line).Lines

    # If there is at least one line, upload immediately.
    if ($prevLineCount -gt 0) {
        if (Upload-Installer-LogFile) {
            Write-Log "Uploaded initial installer log with $prevLineCount lines."
        }
    }

    # Monitor the installer log every 30 seconds until the installer process completes
    while (-not $global:InstallerProcess.HasExited) {
        Start-Sleep -Seconds 30
        if (Test-Path $installerLogPath) {
            $currentLineCount = (Get-Content $installerLogPath | Measure-Object -Line).Lines
            if ($currentLineCount -gt $prevLineCount) {
                if (Upload-Installer-LogFile) {
                    Write-Log "Uploaded installer log update: $currentLineCount lines (was $prevLineCount)."
                }
                $prevLineCount = $currentLineCount
            }
        }
    }

    # Final upload after the installer process finishes
    if (Test-Path $installerLogPath) {
        if (Upload-Installer-LogFile) {
            Write-Log "Final installer log upload complete with $prevLineCount lines."
        }
    }
    Write-Log "$webInstallerName.exe installation completed with Exit Code: $($global:InstallerProcess.ExitCode)"

    # --------------------------------------------------
    # Step 4: Switch Contact Verify to Cloud Processing
    # --------------------------------------------------
    Write-Log "Switch Contact Verify to Cloud Processing"

    $configPath = "C:\ProgramData\Melissa DATA\EVC\EVC.SSIS.Config"

    try {
        if (-Not (Test-Path $configPath)) {
            Write-Log "ERROR: Config file not found at $configPath"
            throw "Config file not found"
        }

        $configXml = [xml](Get-Content $configPath -ErrorAction Stop)
        Write-Log "Loaded config file successfully from $configPath"

        # Switch to Cloud Processing
        if ($configXml.EVC.ProcessingMode) {
            $currentMode = $configXml.EVC.ProcessingMode

            if ($currentMode -eq "WebServices") {
                Write-Log "No change needed. ProcessingMode already set to WebServices."
            } else {
                Write-Log "Current ProcessingMode is '$currentMode'. Updating to 'WebServices'..."
                $configXml.EVC.ProcessingMode = "WebServices"
                $configXml.Save($configPath)
                Write-Log "Updated ProcessingMode to 'WebServices' and saved the file."
            }
        }
        else {
            Write-Log "ProcessingMode tag not found. Creating new <ProcessingMode>WebServices</ProcessingMode> node..."
            $newNode = $configXml.CreateElement("ProcessingMode")
            $newNode.InnerText = "WebServices"
            $configXml.EVC.AppendChild($newNode) | Out-Null
            $configXml.Save($configPath)
            Write-Log "Added new ProcessingMode node with value 'WebServices' and saved the file."
        }

        # Default to Express Email Validation
        if ($configXml.EVC.MailboxLookupMode) {
            $currentMode = $configXml.EVC.MailboxLookupMode

            if ($currentMode -eq "Express") {
                Write-Log "No change needed. MailboxLookupMode already set to Express."
            } else {
                Write-Log "Current MailboxLookupMode is '$currentMode'. Updating to 'Express'..."
                $configXml.EVC.MailboxLookupMode = "Express"
                $configXml.Save($configPath)
                Write-Log "Updated MailboxLookupMode to 'Express' and saved the file."
            }
        }
        else {
            Write-Log "MailboxLookupMode tag not found. Creating new <MailboxLookupMode>Express</MailboxLookupMode> node..."
            $newNode = $configXml.CreateElement("MailboxLookupMode")
            $newNode.InnerText = "Express"
            $configXml.EVC.AppendChild($newNode) | Out-Null
            $configXml.Save($configPath)
            Write-Log "Added new MailboxLookupMode node with value 'Express' and saved the file."
        }
    }
    catch {
        Write-Log "ERROR: Failed to modify Contact Verify config file - $($_.Exception.Message)"
        Exit 1
    }

    # ------------------------------------------------------------------------------------
    # Step 5: Final Step: Upload the Custom Setup Log File to Blob Storage (Final Upload)
    # ------------------------------------------------------------------------------------
    Write-Log "Final upload: Setup Script Completed. Uploading final main log file to Blob Storage..."
    try {
        Invoke-RestMethod -Uri $customSetupLogsUploadUrl -Method Put -InFile $customSetupLogFile -ContentType "text/plain" -Headers @{ "x-ms-blob-type" = "BlockBlob" }
        Write-Log "Final main log file uploaded successfully to Blob"
    }
    catch {
        Write-Log "ERROR: Failed to upload final main log file - $_"
        Exit 1
    }

}
catch {
    Write-Log "ERROR: $_"
    throw $_
    Exit 1
}

Write-Host "Setup Script Completed Successfully!"
