## This is a (very simple) sample Powershell script for executing a list of SQL scripts against respective target databases.
##
## Pipeline passes in a "deploy file" with path defined in $(DEPLOY_FILE_PATH) variable.
## The "deploy file" contains a list of SQL scripts and respective databases.
## Target SQL instance/server will be defined in the pipeline variable $(TARGET_INSTANCE_NAME)".
##
## Below is the format for the "deploy file":
## ;
## ;Begin List
## ;
## database1|..\folder1\folder1_1\script1.sql
## database1|..\folder1\script2.sql
## database2|..\folder2\script3.sql
## ;
## ;End List


$SQLInstanceName="$(TARGET_INSTANCE_NAME)"
$SQLUser="$(USER_NAME)"
$SQLPassword="$(PASSWORDD)"
$deployFile="$(DEPLOY_FILE_PATH)"
$deployLog="$(DEPLOY_LOG_PATH)"


Out-File -FilePath $deployLog
if (Test-Path "$deployFile" -PathType leaf) {
    Write-Output "@@@@@ [$(Get-Date -Format o)] DeployFileList.txt found..."
  }  
else {
    Write-Output "#%#%#%#% [$(Get-Date -Format o)] DeployFileList.txt not found! Aborting!"
    Exit 1
}

Get-Content $deployFile
Write-Output "@@@@@ [$(Get-Date -Format o)] Start executing scripts..."

foreach($line in (Get-Content "$deployFile" | Where-Object { $_.Trim() -ne '' })) {
    if ($line -notlike ";*") {
        $tokens = $line.Split("|")
        $dbName=$tokens[0]
        $scriptPath=$tokens[1]
        Write-Output "@@@@@ [$(Get-Date -Format o)] Executing command: sqlcmd -S $SQLInstanceName -d $dbName -U $SQLUser -P xxxxxx -i $(DeploySource)\Deploy\$scriptPath"
        sqlcmd -S "$SQLInstanceName" -d "$dbName" -U "$SQLUser" -P "$SQLPassword" -b -i "$(DeploySource)\Deploy\$scriptPath" -o "$deployLog"

        if ($LASTEXITCODE -eq 0) {
          Write-Output "@@@@@ [$(Get-Date -Format o)] Command output:"
          Get-Content $deployLog
        }
        else {
          Write-Output "#%#%#%#% [$(Get-Date -Format o)] Script execution failed. Aborting! Command output:"
          Get-Content $deployLog
          Exit 1
        }
    }
  }
Write-Output "@@@@@ [$(Get-Date -Format o)] Finished executing all scripts successfully..."
