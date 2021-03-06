# Parameter to be passed is the name of virtual machine where Test / Development copy needs to be re-purposed
Param(
   [string]$DBVmName
)

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
function createXtremSnapshot ($xmsip,$parentVolumeName,$snapSuffix,$headers)
{
    Write-Host "+++++++++Creating snapshot from "$parentVolumeName
    $cfgOption = 'snapshots'
    $parentVolumes = '['+$parentVolumeName+']'
    $parentVolumes = ($parentVolumes|ConvertTo-Json).ToString()
    $snapSuffix = ($snapSuffix|ConvertTo-Json).ToString()
    $data = @"
    {
        "volume-list":$parentVolumes,
        "snap-suffix":$snapsuffix
    }
"@
     return ExecutePostRestQuery $xmsip $cfgOption $data $headers
}
###
# A function to refresh a pre-existing XtremIO volume copy
# It accepts the source volume or snapshot ID and that of the copy volume that it needs to refresh and invokes ExecutePostRestQuery
###
function refreshXtremSnapshot ($xmsip,$fromVolId,$toVolId,$headers)
{
    $cfgOption = 'snapshots'
    $data = @"
    {
        "from-volume-id":$fromVolId,
        "to-volume-id":$toVolId,
        "no-backup":"true"
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
# A function to check if an XtremIO volume exists
# It accepts the name of the volume and invokes ExecuteGetRestQuery to retrieve properties of the volume object
###
function checkVolume ($xmsip,$volName,$headers)
{
    $cfgOption = 'volumes?name='+$volName
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
# A function to retrieve list of specific initiators of interest used to create lun map
# It accepts list of objects representing FC HBAs on ESX host
# Using these, FC HBAs, it filters the list of XtremIO initiators corresponding to WWNs retrieved from the list of FC HBAs
###
function getInitiatorList ($xmsip, $fcHbas, $headers)
{
    $addresses2Search = $fcHbas|%{"{0:x}" -f $_.PortWorldWideName}
    Write-Host $addresses2Search
    $initiatorList = @()
    $cfgOption = 'initiators'
    $initiators = executeGetRestQuery $xmsip $cfgOption $headers
    foreach ($initiator in $initiators['initiators'])
    {
        Write-Host $initiator['name']
        $cfgOption = "initiators?name=" + $initiator["name"]
        $initiatorObj = ExecuteGetRestQuery $xmsip $cfgOption $headers
        $address = ([String]::join("",$initiatorObj['content']['port-address'].split(":")))
        Write-Host $address
        if ($addresses2Search -eq $address)
        {
           write-host "Initiator Found ..."
           if (-Not $initiatorList -eq $initiatorObj['content']['ig-id'][1]){
               $initiatorList += $initiatorObj['content']['ig-id'][1]
           }
        }
    }
    return $initiatorList
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

$startTime = Get-Date
# Importing SQL powershell module. This module is essential to perform management operations on SQL server
Import-Module sqlps
Add-PSSnapin VMware.VimAutomation.Core
### Creating authentication header object for XMS. This header object is passed to every function call defined above
$xmsip = "10.10.225.170"
$xmsuser = "admin"
$xmspwd = ConvertTo-SecureString "Xtrem10" -AsPlainText -Force
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($xmspwd)
$secPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$basicAuth = ("{0}:{1}" -f $xmsuser,$secPwd)
$EncodeAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
$EncodeBase64Auth = [System.Convert]::ToBase64String($EncodeAuth)
$headers = @{Authorization=("Basic {0}" -f $EncodeBase64Auth)}
### Creation of header object is complete
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
# Establishing a session with vCEtner server
Connect-VIServer -Server 10.10.225.165 -User "administrator@xtrem.sclab" -Password "XtremIO123!"
# Initializing variables. These are the parameters users need to modify
$parentVolumeName = 'SQL1_DBSTORE_2015-11-05_19-35-01-910'	# Name of the production volume name that contains all the database files
$goldSnapSuffix = 'GOLD-snap0'								# Suffix of the gold snapshot (Gen 1)
$goldSnapName = $parentVolumeName + "."+ $goldSnapSuffix
$DBEngine = "TPCE"											# Name of the SQL Server database engine
$DBServer = (Get-VM -Name $DBVmName).Guest.HostName
$machineSnapSuffix = $DBVmName.ToString()
$machineSnapName = $goldSnapName + "." + $machineSnapSuffix
$DBDiskPath = "sql1/sql1.vmdk"								# Path to vmdk disk that contains the data files
$DBName = "tpce"											# Name of the SQL database
$dbExistFlag = 0

# Iterate over collection of databases existing in DB Server and check if pre-existing copy database pointed by parameter $DBEngine exists
$databases = Get-ChildItem SQL\$DBServer\$DBEngine\Databases
write-host $databases
foreach ($db in $databases) {
   if ($db.name -eq $DBName) {
       $dbExistFlag+=1
       break
   }
}

if ($dbExistFlag -eq 1) {
    write-host "a database instance exists with older data"
    # Detach existing database
    (Get-ChildItem SQL\$DBServer).DetachDatabase($DBName,$False)
    sleep 5
    # Create a remote session with the dev/test virtual machine's guest OS
    cd "C:\"
    $rsession = New-CimSession -Computer $DBServer
	# Find the partition that has pre-existing data files pertaining to the database and mark the disk offline
    $disks = Get-Partition -CimSession $rsession
    $disks
    $dLetter = $null
    Foreach ($disk in $disks){
        Write-Host $disk.DriveLetter
        $dLetter = $disk.DriveLetter.ToString()
        if (Test-Path "\\$DBServer\$dLetter$\TPCE_Data\MSSQL_tpce_root.mdf"){
            Write-Host "Drive found"
            Set-Disk -CimSession $rsession -Number $disk.DiskNumber -IsOffline $true
            break
        }
        else{
            Write-Host "Drive not found"
        }

    }
	# Get handle on ESX host and ESX cli using vSphere PowerCLI
    $esxhost = Get-VMHost -VM (Get-VM -Name $DBVmName)
    $esxCLIHandle = Get-EsxCli -VMHost $esxhost
	# Check if the parent volume exists
    $parentVolId = (checkVolume $xmsip $parentVolumeName $headers)['vol-id'][2]
	#Check if a prior existing copy volume (XVC) exists and capture the NAA identifier and XtremIO ID for the XVC
    $machineSnapshotObj = checkSnapshot $xmsip $machineSnapName $headers
    $deviceNaaId = $machineSnapshotObj['naa-name']
    $machineSnapVolId = $machineSnapshotObj['vol-id'][2]
    $goldSnapVolId = $null
	# Remove the VMDK disk that contained the data files
    $diskObj = Get-HardDisk -VM (Get-VM -Name $DBVmName)|where {$_.Filename -match $DBDiskPath}
    Remove-HardDisk -HardDisk $diskObj -Confirm:$false
    $hostStorage = (Get-VMHostStorage -VMHost $esxhost).ScsiLun
    $scsiDevice = $hostStorage -eq $deviceNaaId
    $scsiDeviceId = $null
    Write-Host $hostStorage
    foreach ($scsiDevice in $hostStorage){
        if ($scsiDevice.CanonicalName.split('.')[1] -eq $deviceNaaId){
            $scsiDeviceId = $scsiDevice.CanonicalName
        }
    }
	#Unmount the VMFS datastore that is backed by SCSI disk which is nothing but XVC for the Dev/Test virtual machine
    Write-Host $scsiDeviceId
    Write-Host "######## Unmounting the volume ########"
    $dsObj = Get-Datastore|where {$_.ExtensionData.info.vmfs.extent.diskname -match $scsiDeviceId}
    $vmfsVolObj = $esxCLIHandle.storage.vmfs.extent.list()|where {$_.VolumeName -eq $dsObj.Name}
    $esxCLIHandle.storage.filesystem.unmount($false,"","",$vmfsVolObj.VmfsUUID)
	# Check if gold copy of volume exists and refresh the gold copy from the parent volume
    if (checkSnapshot $xmsip $goldSnapName $headers){
        Write-Host "Gold Snapshot found"
        $goldSnapVolId = (checkSnapshot $xmsip $goldSnapName $headers)['vol-id'][2]
		# Make function call that refreshes the gold copy from parent volume
        Write-Host "Refreshing gold snapshot from volume ........"
        refreshXtremSnapshot $xmsip $parentVolId $goldSnapVolId $headers
        sleep 3
		# Make function call that refreshes the Dev/Test copy (second level copy) from parent volume
        Write-Host "Refreshing machine snapshot from gold snapshot ........"
        refreshXtremSnapshot $xmsip $goldSnapVolId $machineSnapVolId $headers
    }
    else{
	    # If the gold copy does not exist, directly refresh the second level copy meant for Dev/Test environment from the parent volume
        refreshXtremSnapshot $xmsip $parentVolId $machineSnapVolId $headers
    }
	#Refresh the ESX host storage and mount the VMFS datastore by re-signaturing the snapshot volume
    $hostStorage = (Get-VMHostStorage -VMHost $esxhost -Refresh).ScsiLun
    $snapshotDisks = $esxCLIHandle.storage.vmfs.snapshot.extent.list()|where {$_.DeviceName -eq $scsiDeviceId}
    Write-Host "######     ######"
    Write-Host $snapshotDisks
    Write-Host "######     ######"
    $esxCLIHandle.storage.vmfs.snapshot.resignature($snapshotDisks.VolumeName)
    $dataStore = Get-Datastore|where {$_.ExtensionData.Info.Vmfs.Extent.Diskname -eq $scsiDeviceId}
    while (-not $dataStore){
       Write-Host "Waiting for 5 seconds for avaialability of datastore"
       sleep 5
       $dataStore = Get-Datastore|where {$_.ExtensionData.Info.Vmfs.Extent.Diskname -eq $scsiDeviceId}
    }
    write-host $dataStore
	# Add the VMDK disk containing database files to the VM and mark the disk inside guest OS online and writable
    $dbHddObj = New-HardDisk -VM (Get-VM -Name $DBVmName) -DiskPath ('['+$dataStore.name+'] '+$DBDiskPath) -Persistence Persistent
    $rsession = New-CimSession -Computer $DBServer
    $offlineDisks = Get-Disk -CimSession $rsession|where OperationalStatus -eq "offline"
    foreach ( $disk in $offlineDisks ){
       Set-Disk -CimSession $rsession -Number $disk.Number -IsOffline $False 
       Set-Disk -CimSession $rsession -Number $disk.Number -IsReadOnly $False
    }
	# Invoke pre-existing script that will attach the database
    $createDBResult = Invoke-Command -ComputerName $DBServer -ScriptBlock {c:\createDB.ps1}
    write-host $createDBResult
}
else {
    # Check if parent volume exists
    $cfgOption = 'volumes?name='+$parentVolumeName
    $volumes = ExecuteGetRestQuery $xmsip $cfgOption $headers
    # Create gold volume copy (first gen) if it doesn't exist
    $cfgOption = 'snapshots'
    $goldSnapshotObj = 
    if (checkSnapshot $xmsip $goldSnapName $headers){
        Write-Host "Gold Snapshot found"
    }
    else
    {
        Write-Host "Gold snapshot not found, creating one"
        createXtremSnapshot $xmsip $parentVolumeName $goldSnapSuffix $headers
        sleep 3
    }
    # Create second level XVC from the first gen copy created above if it doesn't exist
    if (checkSnapshot $xmsip $machineSnapName $headers)
    {
        Write-Host "Machine Snapshot Found"
    }
    else
    {
        $machineSnapshotObj = createXtremSnapshot $xmsip $goldSnapName $machineSnapSuffix $headers
        write-host $machineSnapshotObj
        sleep 3
    }
    # Get handle on ESX host using vSphere PowerCLI
    $esxhost = Get-VMHost -VM (Get-VM -Name $DBVmName)
	# Get a collection of managed objects representing FC HBAs on ESX hosts.
	# Make a call to 'getInitiatorList' function to get the right set of XtremIO initiator objects representing FC HBAs on ESX host of interest
    $fcHbas = Get-VMHostHba -VMHost $esxhost -Type FibreChannel
    $initiatorList = getInitiatorList $xmsip $fcHbas $headers
    Write-Host "Initiator List: "$initiatorList
	# With the correct set of initiator objects and SVC for Dev/Test virtual machine, create a new lun map between initiator and XVC
    createLunMap $xmsip $initiatorList $machineSnapName $headers
	# Get object representation of second level XVC and capture its NAA identifier
    $machineSnapshotObj = checkSnapshot $xmsip $machineSnapName $headers
    $deviceNaaId = $machineSnapshotObj['naa-name']
    Write-Host $deviceNaaId
	# Rescan all HBAs on ESX host of interest get a handle on SCSI lun object backed by the second gen XVC
    $hostStorage = ($esxhost|Get-VMHostStorage -RescanAllHba).ScsiLun
    $scsiDevice = $hostStorage -eq $deviceNaaId
    $scsiDeviceId = $null
    foreach ($scsiDevice in $hostStorage){
        if ($scsiDevice.CanonicalName.split('.')[1] -eq $deviceNaaId){
            $scsiDeviceId = $scsiDevice.CanonicalName
        }
    }
    Write-Host $scsiDeviceId
	# Get a handle on esxcli of the concerned ESX host and capture the object representation of snapshot volume in the ESX host
	# Mount new VMFS datastore by re-signaturing the snap volume backed by our second gen XVC 
    $esxCLIHandle = Get-EsxCli -VMHost $esxhost
    $snapshotDisks = $esxCLIHandle.storage.vmfs.snapshot.extent.list()|where {$_.DeviceName -eq $scsiDeviceId}
    $esxCLIHandle.storage.vmfs.snapshot.resignature($snapshotDisks.VolumeName)
    $dataStore = Get-Datastore|where {$_.ExtensionData.Info.Vmfs.Extent.Diskname -eq $scsiDeviceId}
    while (-not $dataStore){
       Write-Host "Waiting for 5 seconds for avaialability of datastore"
       sleep 5
       $dataStore = Get-Datastore|where {$_.ExtensionData.Info.Vmfs.Extent.Diskname -eq $scsiDeviceId}
    }
    write-host $dataStore
	# Add the VMDK disk containing database files to the VM and mark the disk inside guest OS online and writable
    $dbHddObj = New-HardDisk -VM (Get-VM -Name $DBVmName) -DiskPath ('['+$dataStore.name+'] '+$DBDiskPath) -Persistence Persistent
    $rsession = New-CimSession -Computer $DBServer
    $offlineDisks = Get-Disk -CimSession $rsession|where OperationalStatus -eq "offline"
    foreach ( $disk in $offlineDisks ){
       Set-Disk -CimSession $rsession -Number $disk.Number -IsOffline $False 
       Set-Disk -CimSession $rsession -Number $disk.Number -IsReadOnly $False
    }
	# Invoke pre-existing script that will attach the database
    $createDBResult = Invoke-Command -ComputerName $DBServer -ScriptBlock {c:\createDB.ps1}
    write-host $createDBResult
}
$EndTime = Get-Date
$EndTime - $startTime
Disconnect-VIServer -Force -Confirm:$false
