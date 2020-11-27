$tessaVersion="3.5.0";
$remotePath="\\someremotepath\TessaDistribsAndScripts";
$localPath="c:\Dev";

New-Item -ItemType Directory -Force -Path $localPath;
Get-ChildItem "$remotePath\*" -File | Copy-Item -Destination $localPath;
Copy-Item -Path "$remotePath\Scripts\Install" -Destination $localPath -Recurse;
Copy-Item -Path "$remotePath\tessa-$tessaVersion" -Destination $localPath -Recurse;
Start-Process -FilePath "$localPath\Install\install_tessa.bat" -PassThru -Wait;