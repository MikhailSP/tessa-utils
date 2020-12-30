Import-Module "$PSScriptRoot\..\Install\MikhailSP.Json.Utils.psm1" -Force -Verbose


class Web
{
    [string] $PoolName
    [string] $Folder
}

class Chronos
{
    [string] $Folder
    [string] $ServiceName
}

class Node
{
    [string] $Name
    [string] $Description
    [string[]] $Roles
    [boolean] $DeployConfiguration
}

class Environment
{
    [string] $Name
    [string] $Description
    [string] $Url
    [Node[]] $Nodes
    [Node] $CurrentNode
}

class InstallSettings
{
    [string] $TempFolder
    [string] $TessaDistrib
    [Web] $Web       
    [Chronos] $Chronos
    [Environment] $Environment
}

function Get-ValueOrExitIfNull{
    [CmdletBinding()]
    param(
        [object] $Json,
        [string] $FileName,
        [string] $Property
    )
    
    foreach($propertyNamePart in $Property.Split("\\.")){
        $Json=$Json."$propertyNamePart"
    }
    if ($Null -eq $Json){
        Write-Error "Не найдено значение $Property в $FileName"
        exit -1
    }
    
    $Json
}

function Get-InstallSettings{
    [OutputType([InstallSettings])]
    [CmdletBinding()]
    param(
        [string] $EnvironmentJsonsPath,
        [string] $EnvironmentName,
        [string] $NodeName,
        [string] $InstallSettingsJsonPath
    )
    
    $environmentFile="$EnvironmentJsonsPath\$EnvironmentName.json"
    
    $installSettingsJson = Get-Content $InstallSettingsJsonPath | Out-String | ConvertFrom-Json
    $environmentJson = Get-Content $environmentFile | Out-String | ConvertFrom-Json
    Merge-Jsons -Target $installSettingsJson -Source $environmentJson.'install-settings'
    
    $tempFolder=Get-ValueOrExitIfNull -Json $installSettingsJson -FileName $InstallSettingsJsonPath `
                                    -Property "roles.common.paths.temp"

    [InstallSettings] $settings=[InstallSettings]::new()
    $settings.TempFolder=Join-Path -Path $tempFolder -ChildPath "TessaDeployPackage"
    
    $settings.TessaDistrib=Get-ValueOrExitIfNull -Json $installSettingsJson -FileName $InstallSettingsJsonPath `
                                    -Property "roles.common.paths.tessa-distrib"

    $settings.Web=[Web]::new()
    $settings.Web.PoolName=Get-ValueOrExitIfNull -Json $installSettingsJson -FileName $InstallSettingsJsonPath `
                                    -Property "roles.web.iis.pool-name"
    $settings.Web.Folder=Get-ValueOrExitIfNull -Json $installSettingsJson -FileName $InstallSettingsJsonPath `
                                    -Property "roles.web.iis.tessa-folder"
    
    $settings.Chronos=[Chronos]::new()
    $settings.Chronos.Folder=Get-ValueOrExitIfNull -Json $installSettingsJson -FileName $InstallSettingsJsonPath `
                                    -Property "roles.chronos.folder"
    $settings.Chronos.ServiceName=Get-ValueOrExitIfNull -Json $installSettingsJson -FileName $InstallSettingsJsonPath `
                                    -Property "roles.chronos.service-name"

    $settings.Environment=[Environment]::new()
    $settings.Environment.Name = Get-ValueOrExitIfNull -Json $environmentJson -FileName $environmentFile `
                                    -Property "name"
    $settings.Environment.Description = Get-ValueOrExitIfNull -Json $environmentJson -FileName $environmentFile `
                                    -Property "description"
    $settings.Environment.Url = Get-ValueOrExitIfNull -Json $environmentJson -FileName $environmentFile `
                                    -Property "url"
    $settings.Environment.Nodes=@()
    
    $nodes=Get-ValueOrExitIfNull -Json $environmentJson -FileName $environmentFile `
                                    -Property "nodes"
    
    foreach ($node in $nodes){
        $nodeObj=[Node]::new()
        $nodeObj.Name=$node.name
        $nodeObj.Description=$node.description
        $nodeObj.Roles=$node.roles
        $nodeObj.DeployConfiguration=$True -eq $node.'deploy-configuration'
        $settings.Environment.Nodes+=$nodeObj
    }
    
    foreach($node in $settings.Environment.Nodes){
        if ($NodeName -eq $node.Name){
            $settings.Environment.CurrentNode=$node
            break
        }
    }
    
    if ($Null -eq $settings.Environment.CurrentNode){
        Write-Error "В файле '$environmentFile' не найдена нода с именем '$NodeName' (nodes.name)"
        exit -1
    }
    
    $settings
}

Export-ModuleMember -Function Get-InstallSettings


