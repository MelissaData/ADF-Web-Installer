# Data Quality Components for SSIS on Azure Data Factory

This project provides a custom setup script and installation files to deploy .NET Framework 3.5 and Melissa SSIS components onto an **Azure Data Factory (ADF) Integration Runtime (SSIS-IR)**. Once deployed, the SSIS-IR will be able to execute SSIS packages that contain Melissa SSIS components.

---

## Getting Started

Follow these steps to set up an SSIS Integration Runtime (SSIS-IR) in Azure Data Factory, configured to run Melissa SSIS components using your own Azure Blob Storage container.

---

## Step-by-Step Instructions

### Step 1: Clone this Repository

Clone this repository to your local machine.

```powershell
git clone https://github.com/MelissaData/ADF-Web-Installer.git
```

---

### Step 2: Download Installation Dependencies
You have two options to obtain the installation dependencies required for setting up the SSIS-IR.

#### Option 1: Using a Download Link:

Download the pre-packaged `DependenciesADF.zip` from the following link:
https://releases.melissadata.net/Download/Interface/WINDOWS/ADF/ANY/latest/DependenciesADF.zip/?ID={{LicenseKey}}

⇒ After downloading, extract the contents into the same directory as your cloned repository.

#### Option 2: Using Melissa Updater:

Download Melissa Updater:  
   - **Windows:**  
     https://releases.melissadata.net/Download/Library/WINDOWS/NET/ANY/latest/MelissaUpdater.exe  
   - **Linux:**  
     https://releases.melissadata.net/Download/Library/LINUX/NET/ANY/latest/MelissaUpdater

Run Melissa Updater from the command line:

```powershell
.\MelissaUpdater.exe file `
    -n "DependenciesADF.zip" `
    -r "latest" `
    -l "{{LicenseKey}}" `
    -y "INTERFACE" -o "WINDOWS" -c "ADF" -a "ANY" `
    -t "{{DownloadDirectory}}"
```
⇒ After downloading, extract the contents into the same directory as your cloned repository.

#### Directory Structure After Extraction
The extracted folder should contain the following:

```
.
├── Setup.ps1
├── main.cmd
├── dotnet-framework-35/
│   └── microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~amd64~~.cab
└── melissa-web-installer/
    └── ADF-DQC-Web.exe
```

---

### Step 3: Create an Azure Blob Storage Container

1. Open your **Azure Storage Account**.
2. Create a **new container** (e.g., `ssis-ir-deployment`).
3. Generate a **SAS Token** with **Read, Add, Create, Write, Delete, and List** permissions for the container.
   - Be sure to **copy the full SAS string**.

   > **Note:** We recommend setting a long expiration date for the SAS token. Azure Data Factory may re-deploy the SSIS-IR at a later time using this token.

---

### Step 4: Configure the Setup Script

Open `Setup.ps1` in a code editor and update the following variables:

```powershell
# Blob Storage Information
$storageAccount  = "<your_storage_account_name>"
$containerName   = "<your_container_name>"

# SAS Token (add the leading '?')
$sasToken        = "<your_blob_container_SAS>" # This should look like "?sp=...&sig=..."

# Melissa Product License Key
$productLicense  = "<your_license_key>"
```

Save the file after making your changes.

---

### Step 5: Upload Deployment Files to Blob

Upload **all files and folders in this repository** to the container you just created.

**Important:**  
Do **not** place files inside an additional folder.  
The SSIS-IR setup process expects `main.cmd` to be at the **top level** of the container.

---

### Step 6: Configure SSIS-IR in Azure Data Factory

1. Navigate to **Azure Data Factory > Integration Runtimes**.
2. Click **+ New** to create a new **Azure-SSIS Integration Runtime**.
3. During setup, under **Integration runtime setup**, be sure to:
   - Check the box:  
     **"Customize your Azure-SSIS Integration Runtime with additional system configurations/component installations"**
   - Provide the full **SAS URL** to your blob container:
     ```
     https://<your_storage_account>.blob.core.windows.net/<your_container_name>?<your_sas_token>
     ```

This allows ADF to run your custom startup script and install Melissa SSIS components automatically during IR provisioning.

---

### Step 7: Start the SSIS-IR

On startup, the SSIS-IR will:
- Install prerequisites (.NET Framework 3.5)
- Install Melissa SSIS components

---

## Logs & Troubleshooting

You can monitor logs from the setup process directly in your blob container:

| Folder Name           | Description                               |
|-----------------------|-------------------------------------------|
| `custom-setup-logs/`  | Logs from the custom setup script         |
| `installer-logs/`     | Logs from the Melissa installer           |

If the IR fails to start or install, check the latest files in those folders for detailed error messages.

---

## Tips

- You can restart the SSIS-IR to re-trigger the setup.
- Make sure you **do not rename** or move files from the repository before uploading.

---

## Contact Us

For free technical support, please call us at 800-MELISSA ext. 4 (800-635-4772 ext. 4) or email us at Tech@Melissa.com.

To purchase this product, contact the Melissa sales department at 800-MELISSA ext. 3 (800-635-4772 ext. 3).
