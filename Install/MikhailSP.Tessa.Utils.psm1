﻿enum Role{
    Web
    Chronos
    Sql
}

enum Version{
    v3_2_0
    v3_5_0
}

class Step
{
    $DebugMode = $False

    [string] $StepName
    [Role[]] $AvailableInServerRoles
    [Version[]] $AvailableInTessaVersions
    [object] $Json

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){}

    [void] DoAndLogStep([Role[]] $ServerRoles, [Version] $TessaVersion)
    {
        Write-Host -ForegroundColor Yellow $this.StepName
        if (!$this.RoleIsAvailable($ServerRoles))
        {
            Write-Host -ForegroundColor Magenta "Step '$($this.StepName)' is not applicable for server roles. Skipping"
            continue
        }

        if ($this.DebugMode)
        {
            Write-Host -ForegroundColor Magenta "Debug mode. Skipping step"
            continue
        }
        if ($Null -eq $this.Json)
        {
            Write-Host -ForegroundColor Magenta "No config section for step '$( $this.StepName )' in prerequisites.json. Skipping"
            continue
        }

        $this.DoStep($ServerRoles, $TessaVersion)
    }
    
    [object] GetValueOrLogError([string] $jsonSection)
    {
        [object] $value=$this.Json."$jsonSection";
        if ($Null -eq $value)
        {
            throw "No section '$jsonSection' value in config"
        }
        return $value
    }
    
    [Boolean] RoleIsAvailable([Role[]] $ServerRoles)
    {
        if ($Null -eq $this.AvailableInServerRoles)
        {
            return $True
        }
        if ($Null -eq $ServerRoles)
        {
            return $False
        }
        foreach ($availableRole in $this.AvailableInServerRoles)
        {
            foreach ($serverRole in $ServerRoles)
            {
                if ($serverRole -eq $availableRole)
                {
                    return $True
                }
            }
        }
        return $False
    }

    Step([string] $stepName, [object] $json, [Role[]] $availableInServerRoles, [Version[]] $availableInTessaVersions)
    {
        $this.StepName = $stepName
        $this.AvailableInServerRoles = $availableInServerRoles
        $this.AvailableInTessaVersions = $availableInTessaVersions
        $this.Json = $json
    }

    Step([string] $stepName, [object] $json, [Role[]] $availableInServerRoles)
    {
        $this.StepName = $stepName
        $this.AvailableInServerRoles = $availableInServerRoles
        $this.Json = $json
    }

    Step([string] $stepName, [object] $json)
    {
        $this.StepName = $stepName
        $this.Json = $json
    }

    Step([string] $stepName)
    {
        $this.StepName = $stepName
    }
}

class NewKeyboardLayoutStep : Step
{
    NewKeyboardLayoutStep([object] $json): base("Adding new keyboard layout", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $newLayout = $this.GetValueOrLogError("layout")
        $UserLanguageList = New-WinUserLanguageList -Language "en-US";
        $UserLanguageList.Add($newLayout);
        Set-WinUserLanguageList -LanguageList $UserLanguageList -Force;
        Write-Host -ForegroundColor Gray "Added new keyboard layout '$newLayout'";
    }
}

class SetTimeZoneStep : Step
{
    SetTimeZoneStep([object] $json): base("Setting time zone", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $timezone =  $this.GetValueOrLogError("name")
        Set-TimeZone -Name $timezone;
        Write-Host -ForegroundColor Gray "Time zone set to '$timezone'";
    }
}

class InstallIisStep: Step
{
    InstallIisStep([object]$json): base("Installing IIS", $json, @([Role]::Web)){}
    
    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        switch($TessaVersion)
        {
            ([Version]::v3_2_0)
            {
                Write-Host "Installing IIS with .Net Framework 4.5"
                Install-WindowsFeature -Name Web-Server, Web-Windows-Auth, Web-Mgmt-Console, Web-Asp-Net45, NET-WCF-HTTP-Activation45 -Restart
            }    
            ([Version]::v3_5_0)
            {
                Write-Host "Installing IIS without .Net Framework"
                Install-WindowsFeature -Name Web-Server, Web-Windows-Auth, Web-Mgmt-Console -Restart
            }    
            default{throw "Unknown version '$TessaVersion' for step '$($this.StepName)'"}
        }
        Write-Host -ForegroundColor Gray "IIS installed";
    }
}

class NewSslCertificateStep : Step {
    NewSslCertificateStep([object]$json): base("Creating self-signed SSL certificate and bindings", $json, @([Role]::Web)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        Import-Module WebAdministration
        Set-Location IIS:\SslBindings

        $webSite=$this.GetValueOrLogError("site")
        $webPort=$this.GetValueOrLogError("port")
        $dnsName=$this.GetValueOrLogError("dns-name")
        Write-Verbose "Creating binding for site '$webSite' on $webPort port with certificate for '$dnsName'"

        New-WebBinding -Name $webSite -IP "*" -Port $webPort -Protocol https

        $c = New-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation cert:\LocalMachine\My

        $c | New-Item 0.0.0.0!$webPort
        Write-Host -ForegroundColor Gray "Self-signed SSL certificate and bindings for '$webSite' on $webPort port created";
    }
}

class InstallCoreHostingRuntimeStep: Step
{
    InstallCoreHostingRuntimeStep([object]$json): base("Installing .NET Core Runtime & Windows Hosting Bundle", $json, @([Role]::Web)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        switch($TessaVersion)
        {
            ([Version]::v3_5_0)
            {
                #
                # Reference: https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-3.1
                #
                $tempFolder="c:\temp\" #TODO get from prerequisites.json roles.common.paths.temp
                $whbUrl=$this.GetValueOrLogError("url")
                Write-Verbose "Downloading installer from '$whbUrl' to '$tempFolder'"

                if( ![System.IO.Directory]::Exists( $tempFolder ) )
                {
                    New-Item -ItemType Directory -Force -Path $tempFolder
                }
                
                $whbInstallerFile = $tempFolder + [System.IO.Path]::GetFileName( $whbUrl )

                Invoke-WebRequest -Uri $whbUrl -OutFile $whbInstallerFile
                Write-Host "Windows Hosting Bundle Installer downloaded. Installing..."
                Start-Process -FilePath $whbInstallerFile -ArgumentList "/passive" -Wait
                net stop was /y
                net start w3svc     
            }
            default{throw "Unknown version '$TessaVersion' for step '$($this.StepName)'"}
        }
        Write-Host -ForegroundColor Gray ".NET Core Runtime & Windows Hosting Bundle installed";
    }
}

class AddUserToIusrsStep : Step
{
    AddUserToIusrsStep([object] $json): base("Adding tessa pool account to IIS_IUSRS group", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $poolAccount =  $this.GetValueOrLogError("pool-account")

        $de = [ADSI]"WinNT://$env:computername/IIS_IUSRS,group";        
        $appPoolPartOfAddress=$poolAccount.Replace("\","/");
        $de.psbase.Invoke("Add",([ADSI]"WinNT://$appPoolPartOfAddress").path);
    
        Write-Host -ForegroundColor Gray "Tessa pool account '$poolAccount' was added to IIS_IUSRS group";
    }
}

class CreateAppPool : Step
{
    CreateAppPool([object] $json): base("Creating tessa application pool", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $poolName =  $this.GetValueOrLogError("pool-name")
        $poolAccount =  $this.GetValueOrLogError("pool-account")
        $poolPassword =  $this.GetValueOrLogError("pool-account-password")
        Write-Verbose "Creating tessa application pool '$poolName'. Account: '$poolAccount', Password: '$poolPassword'"
    
        Import-Module WebAdministration
    
        $poolPath="IIS:\AppPools\" + $poolName
        if(!(Test-Path ($poolPath)))
        {
            $appPool = New-Item ($poolPath)
            Set-ItemProperty -Path $poolPath -Name processmodel.identityType -Value 3
            Set-ItemProperty -Path $poolPath -Name processmodel.userName -Value $poolAccount
            Set-ItemProperty -Path $poolPath -Name processmodel.password -Value $poolPassword
            Set-ItemProperty -Path $poolPath -Name processmodel.maxProcesses -Value (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
            Set-ItemProperty -Path $poolPath -Name managedRuntimeVersion -Value ""
            Write-Host -ForegroundColor Gray "Tessa application pool '$poolName' was created. Pool account '$poolAccount'"
        } 
        else
        {
            Write-Host -ForegroundColor Gray "Tessa application pool '$poolName' already created. Skipping step."     
        }     
    }
}


class CopyTessaWebStep : Step
{
    CopyTessaWebStep([object] $json): base("Copying tessa web files to IIS folder", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $tessaFolder =  $this.GetValueOrLogError("tessa-folder")
        $tessaDistrib= "c:\Dev\tessa-3.5.0" #TODO get from prerequisites.json roles.common."tessa-distrib"
        $licenseFile= "c:\Dev\МОНТ.tlic" #TODO get from prerequisites.json roles.common.license
    
        if(![System.IO.Directory]::Exists($tessaFolder))
        {
            New-Item -ItemType Directory -Force -Path $tessaFolder
        }
    
        Copy-Item -Path "$tessaDistrib\Services\*" -Destination $tessaFolder -Recurse
    
        Write-Host -ForegroundColor Gray "Copying Tessa license file to '$tessaFolder'";
        Copy-Item -Path "$licenseFile" -Destination $tessaFolder

        Write-Host -ForegroundColor Gray "Tessa web files were copied from '$tessaDistrib\Services' to Tessa folder in IIS '$tessaFolder'";
    }
}

class ConvertFolderToWebApplicationStep : Step
{
    ConvertFolderToWebApplicationStep([object] $json): base("Converting Tessa folder in IIS to a Web Application", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $site =  $this.GetValueOrLogError("site")
        $poolName =  $this.GetValueOrLogError("pool-name")
        ConvertTo-WebApplication "IIS:\Sites\$site\tessa\web" -ApplicationPool $poolName
        Write-Host -ForegroundColor Gray "Tessa folder in IIS was converted to a Web Application";
    }
}

class RequireSslStep : Step
{
    RequireSslStep([object] $json): base("Require SSL for Tessa", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $site =  $this.GetValueOrLogError("site")
        Set-WebConfiguration -PSPath "machine/webroot/apphost" -Location "$site/tessa" -Filter "system.webserver/security/access" -Value "Ssl"
        Write-Host -ForegroundColor Gray "Tessa application set to require SSL";
    }
}

class EnableWinAuthStep : Step
{
    RequireSslStep([object] $json): base("Enabling windows authentication for Tessa", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $site =  $this.GetValueOrLogError("site")
        Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name Enabled -Value True -PSPath "IIS:\" -Location "$site/tessa/web"
        Write-Host -ForegroundColor Gray "Windows authentication enabled on Tessa application";
    }
}

function Install-TessaPrerequisites
{
    <#
        Установить пререквизиты (вещи, обязательные для установки Tessa, например, IIS для сервера приложений)
        .PARAMETER ServerRoles Роли сервера
        .PARAMETER TessaVersion Версия Тессы, пререквизиты к которой надо поставить
    #>
    [CmdletBinding()]
    param(
        [Role[]]
        $ServerRoles,
        
        [Version]
        $TessaVersion
    )

    Write-Verbose "Installing Tessa $TessaVersion prerequisites for roles $( $ServerRoles|foreach { $_ } )"

    $json = Get-Content "$PSScriptRoot\config\prereq\prerequisites.json" | Out-String | ConvertFrom-Json
    $commonRole = $json.roles.common
    $webRole = $json.roles.web
    $chronosRole = $json.roles.chronos
    $sqlRole = $json.roles.sql

    [Step[]]$steps = @()
    $steps += [NewKeyboardLayoutStep]::new($commonRole.'keyboard-layout')
    $steps += [SetTimeZoneStep]::new($commonRole.'timezone')
    $steps += [InstallIisStep]::new($webRole.'iis')
    $steps += [NewSslCertificateStep]::new($webRole.'iis')
    $steps += [InstallCoreHostingRuntimeStep]::new($webRole.'core-runtime')
    $steps += [AddUserToIusrsStep]::new($webRole.'iis')
    $steps += [CreateAppPool]::new($webRole.'iis')
    $steps += [CopyTessaWebStep]::new($webRole.'iis')
    $steps += [ConvertFolderToWebApplicationStep]::new($webRole.'iis')
    $steps += [RequireSslStep]::new($webRole.'iis')
    $steps += [EnableWinAuthStep]::new($webRole.'iis')


    foreach ($step in $steps)
    {
        $step.DoAndLogStep($ServerRoles, $TessaVersion)
    }
}

Export-ModuleMember -Function Install-TessaPrerequisites