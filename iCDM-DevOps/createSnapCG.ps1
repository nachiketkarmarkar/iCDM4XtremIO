# Adding exception to accept a self - signed certificate or accepting an X509Certificate that previously didn't exist
add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem){
                return true;
            }
        }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy



###
# A generic wrapper function that queries XtremIO REST API using HTTP/GET
# Retrieves and lists existing configuration of an object or multiple objects
###
function ExecuteGetRestQuery ($xmsip,$cfgOption,$headers)
{
    try
    {
       
        $baseUrl = "https://"+$xmsip
        $resUrl = '/api/json/v2/types/'
        $url = $baseUrl + $resUrl + $cfgOption
        Write-Host "ExecuteGetRestQuery()::"$url
        $jsonserial = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
        $jsonserial.MaxJsonLength = [int]::MaxValue
        $result = $jsonserial.DeserializeObject((Invoke-WebRequest -Method GET -Uri $url -Headers $headers))
        return $result
        }
    catch{
        return $false
        }
    
}
###
# A generic wrapper function that queries XtremIO REST API using HTTP/POST
# Creates a new object with specified properties
###
function ExecutePostRestQuery ($xmsip,$cfgOption,$data,$headers)
{
    $baseUrl = "https://"+$xmsip
    $resUrl = '/api/json/v2/types/'
    $url = $baseUrl + $resUrl + $cfgOption
    Write-Host $url
    Write-Host $data
    $jsonserialInput = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    $jsonserialOutput = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    $jsonserialInput.MaxJsonLength = [int]::MaxValue
    $jsonSerialOutput.MaxJsonLength = [int]::MaxValue
    $result = (Invoke-RestMethod -Method POST -Uri $url -Body $data -Headers $headers)
    return $result
}
###
# A function to create XtremIO snapshot on a single volume or an existing snapshot
# It accepts name of the object (volume or a snapshot) name and snapshot suffix as arguments and invokes ExecutePostRestQuery
###
function createXtremSnapshot ($xmsip,$parentVolumeName,$snapSuffix,$ssName,$headers)
{
    Write-Host "+++++++++Creating snapshot from "$parentVolumeName
    $cfgOption = 'snapshots'
    $parentVolumes = '['+$parentVolumeName+']'
    $parentVolumes = ($parentVolumes|ConvertTo-Json).ToString()
    $snapSuffix = ($snapSuffix|ConvertTo-Json).ToString()
    $ssName = ($ssName|ConvertTo-Json).ToString()
    $data = @"
    {
        "volume-list":$parentVolumes,
        "snap-suffix":$snapsuffix,
        "snapshot-set-name":$ssName
    }
"@
     return ExecutePostRestQuery $xmsip $cfgOption $data $headers
}
###
# A function to create XtremIO snapshot on a single consistency grou
# It accepts name of the consistency group and snapshot suffix as arguments and invokes ExecutePostRestQuery
###
function createXtremSnapshotByCG ($xmsip,$cgName,$snapSuffix,$ssName,$headers)
{
    Write-Host "+++++++++Creating snapshot from "$parentVolumeName
    $cfgOption = 'snapshots'
    $cgName = ($cgName|ConvertTo-Json).ToString()
    $snapSuffix = ($snapSuffix|ConvertTo-Json).ToString()
    $ssName = ($ssName|ConvertTo-Json).ToString()
    $data = @"
    {
        "consistency-group-id":$cgName,
        "snap-suffix":$snapsuffix,
        "snapshot-set-name":$ssName
    }
"@
     return ExecutePostRestQuery $xmsip $cfgOption $data $headers
}

###
# A function to create XtremIO snapshot on a single snapshot set
# It accepts name of the snapshot set and snapshot suffix as arguments and invokes ExecutePostRestQuery
###
function createXtremSnapshotBySS ($xmsip,$srcSSName,$snapSuffix,$targetSSName,$headers)
{
    Write-Host "+++++++++Creating snapshot from "$parentVolumeName
    $cfgOption = 'snapshots'
    $srcSSName = ($srcSSName|ConvertTo-Json).ToString()
    $snapSuffix = ($snapSuffix|ConvertTo-Json).ToString()
    $targetSSName = ($targetSSName|ConvertTo-Json).ToString()
    $data = @"
    {
        "snapshot-set-id":$srcSSName,
        "snap-suffix":$snapsuffix,
        "snapshot-set-name":$targetSSName
    }
"@
     return ExecutePostRestQuery $xmsip $cfgOption $data $headers
}


###
# A function to check if an XtremIO volume copy exists
# It accepts the name of the copy volume and invokes ExecuteGetRestQuery to retrieve properties of the copy volume object
###
function checkSnapshot ($xmsip,$snapshotName,$headers)
{
    $cfgOption = 'snapshots?name='+$snapshotName
    $snapshot = ExecuteGetRestQuery $xmsip $cfgOption $headers
    if ( $snapshot -ne $null)
    {
        return $snapshot['content']
    }
    else
    {
        return $false
    }
      
}
###
# A function to NAA ID of an XtremIO volume
# It accepts the name of the volume and invokes ExecuteGetRestQuery to retrieve properties of the copy volume object
###
function getVolDeviceID ($xmsip,$volName,$headers)
{
    $cfgOption = 'volumes?name='+$volName
    $vol = ExecuteGetRestQuery $xmsip $cfgOption $headers
    if ( $vol -ne $null)
    {
        $volContent = $vol['content']
        return $volContent['naa-name']
    }
    else
    {
        return $false
    }
      
}

###
# This function is used to create lun mapping between a set of initiators and volume
# It accepts a list of initiators, the volume name and invokes ExecutePostRestQuery to create a 
# new lun map between every initiator in the list and the volume
###
function createLunMap($xmsip, $initiatorList, $volName, $headers)
{
    $cfgOption = 'lun-maps'
    $volName = ($volName|ConvertTo-Json).ToString()
    foreach ($initiator in $initiatorList)
    {
        $initiator = ($initiator|ConvertTo-Json).ToString()
        $data = @"
        {
          "vol-id":$volName,
          "ig-id":$initiator
        }
"@
        ExecutePostRestQuery $xmsip $cfgOption $data $headers
    }
}
###
# A function to mount a disk partition inside the operating system backed by device ID
# It accepts the NAA ID of an XtremIO volume, drive letter for logical partition
# and invokes ExecuteGetRestQuery to retrieve properties of the copy volume object
###
function mountDisk ($deviceID, $driveLetter, $volLabel) {

    $newDisk = Get-Disk | Where UniqueId -eq $deviceID
    Set-Disk -Number ($newDisk.Number) -IsReadOnly $false
    Set-Disk -Number ($newDisk.Number) -IsOffline $false

    Start-Sleep -Seconds 1
    ## Assign drive letter
    $newPar = Get-Partition -DiskNumber ($newDisk.Number)
    if (-not ($newPar.DriveLetter -eq $driveLetter)) {
        Set-Partition -DriveLetter $newPar.DriveLetter -NewDriveLetter $driveLetter
        Set-Volume -DriveLetter $driveLetter -NewFileSystemLabel $volLabel
     }
}

###
# This function does a SCSI rescan to discover the new snapshot volume, mounts the volume to 
# the file system, and restore the SQL Server database from mdf & ldf file via the attach method.
###
function mountAndRecover ($dataDeviceID, $logDeviceID, $dbName, $dataDrive, $volLabelData, $logDrive, $volLabelLog, $dataPath, $logPath) {

    ## Rescan and bring new disk online
    Update-HostStorageCache

    Start-Sleep -Seconds 1
    ## Mount disks
    mountDisk $dataDeviceID $dataDrive $volLabelData
    mountDisk $logDeviceID $logDrive $volLabelLog

    ## Attach database
    $sqlStmt = "create database "+ $dbName+" on (filename = N'"+$dataPath+"'), (filename = N'"+$logPath+"') for attach"
    if ((Test-Path -Path $datapath) -and (Test-path -Path $logpath)){
 	    # Attach Database
        Invoke-SqlCmd -Query $sqlStmt
    }

}


# Importing SQL powershell module. This module is essential to perform management operations on SQL server
Import-Module sqlps -DisableNameChecking

### Creating authentication header object for XMS. This header object is passed to every function call defined above
$xmsip = "xmsip"
$xmsuser = "username"
$xmspwd = ConvertTo-SecureString "password" -AsPlainText -Force
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($xmspwd)
$secPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$basicAuth = ("{0}:{1}" -f $xmsuser,$secPwd)
$EncodeAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
$EncodeBase64Auth = [System.Convert]::ToBase64String($EncodeAuth)
$headers = @{Authorization=("Basic {0}" -f $EncodeBase64Auth)}
### Creation of header object is complete


## Step 1: Create generation 1 snapshot for stage env
createXtremSnapshotByCG $xmsip "cg-sql-prod" "g1" "ss-sql-prod.g1" $headers

## Step 2: Mount snapshot volume to stage host, create stage DB
createLunMap $xmsip "lgsc040" "sql-prod.g1" $headers
createLunMap $xmsip "lgsc040" "sql-prod-log.g1" $headers
$dataDeviceID = getVolDeviceID $xmsip "sql-prod.g1" $headers
$logDeviceID = getVolDeviceID $xmsip "sql-prod-log.g1" $headers
mountAndRecover $dataDeviceID $logDeviceID "stageDB" "M" "sql-stage" "N" "sql-stage-log" "M:\prod.mdf" "N:\prod_log.ldf"

## Step 3: Run data scubbing scripts to perform data masking
Invoke-SqlCmd -InputFile "C:\scripts\dataMasking.sql"
 

## Step 4: Create generation 2 snapshot from stage 
createXtremSnapshotBySS $xmsip "ss-sql-prod.g1" "g2" "ss-sql-prod.g1.g2" $headers

## Step 5: Mount snapshot volume to test host, create test DB
createLunMap $xmsip "lgsc040" "sql-prod.g1.g2" $headers
createLunMap $xmsip "lgsc040" "sql-prod-log.g1.g2" $headers
$dataDeviceID = getVolDeviceID $xmsip "sql-prod.g1.g2" $headers
$logDeviceID = getVolDeviceID $xmsip "sql-prod-log.g1.g2" $headers
mountAndRecover $dataDeviceID $logDeviceID "testDB" "S" "sql-test" "T" "sql-test-log" "S:\prod.mdf" "T:\prod_log.ldf"




