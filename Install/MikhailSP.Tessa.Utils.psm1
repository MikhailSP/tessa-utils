enum Role{
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


    foreach ($step in $steps)
    {
        $step.DoAndLogStep($ServerRoles, $TessaVersion)
    }
}

Export-ModuleMember -Function Install-TessaPrerequisites