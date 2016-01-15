$allDrives=gwmi win32_LogicalDisk -filter DriveType=3
$dbFileDrive=$null
foreach ($drive in $allDrives.DeviceID){
   if (Test-Path $drive"\TPCE_Data\MSSQL_tpce_root.mdf"){
      $dbFileDrive=$drive[0]
   }
}
Write-Host $dbFileDrive
& sqlcmd -E -S "sql2\TPCE" -v "drive=$dbFileDrive" -i C:\createTpceDatabase.sql
