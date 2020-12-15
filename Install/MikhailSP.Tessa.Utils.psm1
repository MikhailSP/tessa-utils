Import-Module "$PSScriptRoot\MikhailSP.Json.Utils.psm1" -Force -Verbose

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
        
        if ($this.Json.disabled){
            Write-Host -ForegroundColor Magenta "Step disabled. Skipping step"
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
    [string] $TempFolder
    
    InstallCoreHostingRuntimeStep([object]$json, [string] $tempFolder): base("Installing .NET Core Runtime & Windows Hosting Bundle", $json, @([Role]::Web)){
        $this.TempFolder=$tempFolder
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        switch($TessaVersion)
        {
            ([Version]::v3_5_0)
            {
                #
                # Reference: https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-3.1
                #
                $whbUrl=$this.GetValueOrLogError("url")
                Write-Verbose "Downloading installer from '$whbUrl' to '$($this.TempFolder)'"

                if( ![System.IO.Directory]::Exists( $this.TempFolder ) )
                {
                    New-Item -ItemType Directory -Force -Path $this.TempFolder
                }
                
                $whbInstallerFile = $this.TempFolder + [System.IO.Path]::GetFileName( $whbUrl )

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
    AddUserToIusrsStep([object] $json): base("Adding tessa pool account to IIS_IUSRS group", $json, @([Role]::Web)){}

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
    CreateAppPool([object] $json): base("Creating tessa application pool", $json,[Role]::Web){}

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
    [string] $TessaDistribPath
    [string] $LicenseFile

    CopyTessaWebStep([object] $json, [string] $tessaDistribPath, [string] $licenseFile): base("Copying tessa web files to IIS folder", $json, @([Role]::Web)){
        $this.TessaDistribPath=$tessaDistribPath
        $this.LicenseFile=$licenseFile
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $tessaFolder =  $this.GetValueOrLogError("tessa-folder")
    
        if(![System.IO.Directory]::Exists($tessaFolder))
        {
            New-Item -ItemType Directory -Force -Path $tessaFolder
        }
    
        Copy-Item -Path "$($this.TessaDistribPath)\Services\*" -Destination $tessaFolder -Recurse
    
        Write-Host -ForegroundColor Gray "Copying Tessa license file to '$tessaFolder'";
        Copy-Item -Path $this.LicenseFile -Destination $tessaFolder

        Write-Host -ForegroundColor Gray "Tessa web files were copied from '$($this.TessaDistribPath)\Services' to Tessa folder in IIS '$tessaFolder'";
    }
}

class ConvertFolderToWebApplicationStep : Step
{
    ConvertFolderToWebApplicationStep([object] $json): base("Converting Tessa folder in IIS to a Web Application", $json, @([Role]::Web)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $site =  $this.GetValueOrLogError("site")
        $poolName =  $this.GetValueOrLogError("pool-name")
        ConvertTo-WebApplication "IIS:\Sites\$site\tessa\web" -ApplicationPool $poolName
        Write-Host -ForegroundColor Gray "Tessa folder in IIS was converted to a Web Application";
    }
}

class RequireSslStep : Step
{
    RequireSslStep([object] $json): base("Require SSL for Tessa", $json,[Role]::Web){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $site =  $this.GetValueOrLogError("site")
        Set-WebConfiguration -PSPath "machine/webroot/apphost" -Location "$site/tessa" -Filter "system.webserver/security/access" -Value "Ssl"
        Write-Host -ForegroundColor Gray "Tessa application set to require SSL";
    }
}

class EnableWinAuthStep : Step
{
    EnableWinAuthStep([object] $json): base("Enabling windows authentication for Tessa", $json, @([Role]::Web)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $site =  $this.GetValueOrLogError("site")
        Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name Enabled -Value True -PSPath "IIS:\" -Location "$site/tessa/web"
        Write-Host -ForegroundColor Gray "Windows authentication enabled on Tessa application";
    }
}

class GenerateNewSecurityTokenStep : Step
{
    [string] $TessaDistribPath
    
    GenerateNewSecurityTokenStep([object] $json, [string] $tessaDistribPath): base("Generating new security tokens (Signature and Cipher) for Tessa web services", $json, @([Role]::Web)){
        $this.TessaDistribPath=$tessaDistribPath
    }

    [void] UpdateToken([string] $tokenType,[string] $tadminFile, [string] $tessaFolderInIis){
        $result=Execute-CommandWithExceptionOnErrorCode -CommandPath $tadminFile -CommandArguments "GetKey","$tokenType"
        $token=$result.stdout
        Write-Verbose "Generated new $tokenType token: '$token'"
        $result=Execute-CommandWithExceptionOnErrorCode -CommandPath $tadminFile -CommandArguments "SetKey","$tokenType","/path:$tessaFolderInIis","/value:$token"
        Write-Verbose "Saved $tokenType token: '$($result.stdout)'"
    }
    
    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $tessaFolderInIis =  $this.GetValueOrLogError("tessa-folder")
        $tessaPoolName =  $this.GetValueOrLogError("pool-name")
        $tadminFile=Join-Path -Path $this.TessaDistribPath -Child "Tools\tadmin.exe"
        Write-Verbose "Prepare for running tadmin from '$tadminFile' for Tessa IIS Path '$tessaFolderInIis'"

        $this.UpdateToken("Signature", $tadminFile, $tessaFolderInIis)
        $this.UpdateToken("Cipher", $tadminFile, $tessaFolderInIis)
        Write-Host -ForegroundColor Gray "New security tokens for Tessa web services generated and set";

        Restart-WebAppPool -Name $tessaPoolName
        Write-Host -ForegroundColor Gray "Application pool '$tessaPoolName' restarted";
    }
}

class ChangeAppJsonStep : Step
{
    [string] $EnvironmentName
    [string] $AppJsonPath
    
    ChangeAppJsonStep([object] $json, [string] $environmentName, [string] $appJsonPath): base("Changing app.json (merging with custom.json)", $json){
        $this.EnvironmentName=$environmentName
        $this.AppJsonPath=$appJsonPath
    }
    
    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $environmentJsonFile="$PSScriptRoot\config\environments\$($this.EnvironmentName).json"
        $environmentWebJsonFile="$PSScriptRoot\config\environments\$($this.EnvironmentName).web.json"
        $environmentWebChronosFile="$PSScriptRoot\config\environments\$($this.EnvironmentName).chronos.json"
        $filesToMerge=@()
        $filesToMerge+=$this.AppJsonPath
        $filesToMerge+=$environmentJsonFile
        if ($ServerRoles.Contains([Role]::Web)){
            $filesToMerge+=$environmentWebJsonFile
        }   
        if ($ServerRoles.Contains([Role]::Chronos)){
            $filesToMerge+=$environmentWebChronosFile
        }
        Write-Verbose "Files '$filesToMerge' will be merged into '$($this.AppJsonPath)'"
    
        Copy-Item $this.AppJsonPath -Destination "$($this.AppJsonPath).backup";
        Merge-JsonFiles -TargetFile $this.AppJsonPath -FilesToMerge $filesToMerge
        Write-Host -ForegroundColor Gray "app.json changed (merged with custom.json)";
    }
}


class CopyChronosStep : Step
{
    [string] $TessaDistribPath
    [string] $LicenseFile

    CopyChronosStep([object] $json, [string] $tessaDistribPath,[string] $licenseFile): base("Copying Chronos to folder", $json, @([Role]::Chronos)){
        $this.TessaDistribPath=$tessaDistribPath
        $this.LicenseFile=$licenseFile
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $chronosFolder =  $this.GetValueOrLogError("folder")
        Copy-Item -Path "$($this.TessaDistribPath)\Chronos" -Destination $chronosFolder -Recurse;
        Copy-Item -Path $this.LicenseFile -Destination $chronosFolder -Recurse;
        Write-Host -ForegroundColor Gray "Chronos was copied to folder";
    }
}

class AttachSqlIsoStep : Step
{
    AttachSqlIsoStep([object] $json): base("Attaching SQL ISO file", $json, [Role]::Sql){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $isoPath =  $this.GetValueOrLogError("iso-path")
        $mountResult=Mount-DiskImage -ImagePath $isoPath -PassThru;
        $global:SqlDistribDriveLetter=($mountResult | Get-Volume).DriveLetter;
        Write-Host -ForegroundColor Gray "SQL ISO file attached";
    }
}

class InstallSqlStep : Step
{
    InstallSqlStep([object] $json): base("Installing MS SQL Server", $json, @([Role]::Sql)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $iniFile =  $this.GetValueOrLogError("ini-file")
        $admin =  $this.GetValueOrLogError("admin")
        $admin2 =  $this.GetValueOrLogError("admin2")
        $sqlSetupPath="$($global:SqlDistribDriveLetter):/setup.exe"
        $arguments="/ConfigurationFile=$iniFile /IACCEPTSQLSERVERLICENSETERMS /SQLSYSADMINACCOUNTS=""BUILTIN\Administrators"" ""$admin"" ""$admin2""";
        Write-Host -ForegroundColor Gray "Запуск '$sqlSetupPath' с параметрами '$arguments'"
        Start-Process -FilePath $sqlSetupPath -ArgumentList $arguments -Wait
        Write-Host -ForegroundColor Gray "MS SQL Server installed";
    }
}

class InstallSsmsStep : Step
{
    [string] $TempFolder
    
    InstallSsmsStep([object] $json, [string] $tempFolder): base("Installing MS SQL Server Management Studio", $json, @([Role]::Sql)){
        $this.TempFolder=$tempFolder
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        if(![System.IO.Directory]::Exists($this.TempFolder))
        {
            New-Item -ItemType Directory -Force -Path $this.TempFolder;
        }
    
        $ssmsInstaller = "$($this.TempFolder)\SSMS-Setup-RUS.exe";
        if (Test-Path -Path $ssmsInstaller){
            Write-Verbose "SQL Server Management Studio Installer already downloaded"
        }
        else {
            $sqlManagementStudioUrl="https://aka.ms/ssmsfullsetup"
            Invoke-WebRequest -Uri $sqlManagementStudioUrl  -OutFile $ssmsInstaller
            Write-Host "SQL Server Management Studio Installer downloaded"
        } 

        Start-Process -FilePath $ssmsInstaller -ArgumentList "/passive" -Wait
        Write-Host -ForegroundColor Gray "MS SQL Server Management Studio installed";
    }
}

class DetachSqlIsoStep : Step
{
    DetachSqlIsoStep([object] $json): base("Detaching SQL ISO file", $json, @([Role]::Sql)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $isoPath =  $this.GetValueOrLogError("iso-path")
        Dismount-DiskImage -ImagePath $isoPath;
        Write-Host -ForegroundColor Gray "SQL ISO file detached";
    }
}

class DownloadAndInstallStep : Step
{
    [string] $TempFolder
    [string] $SoftName
    
    DownloadAndInstallStep([object] $json, [string] $tempFolder, [string] $softName): base("Downloading and installing $softName", $json){
        $this.TempFolder=$tempFolder
        $this.SoftName=$softName
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $url=$this.GetValueOrLogError("url")
        $argument=$this.GetValueOrLogError("argument")
        if(![System.IO.Directory]::Exists($this.TempFolder))
        {
            New-Item -ItemType Directory -Force -Path $this.TempFolder;
        }
        $installer = $this.TempFolder + [System.IO.Path]::GetFileName($url)
        if (Test-Path $installer){
            Write-Verbose "$($this.SoftName) installer already downloaded"
        }
        else {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $installer
            Write-Host "$($this.SoftName) installer downloaded"
        }
        Start-Process -FilePath $installer -ArgumentList $argument -Wait
        Write-Host -ForegroundColor Gray "$($this.SoftName) installed";
    }
}


class EnablePsRemotingStep : Step
{
    EnablePsRemotingStep([object] $json): base("Enabling PowerShell remoting", $json){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        Enable-PSRemoting -Force;
        Write-Host -ForegroundColor Gray "PowerShell remoting enabled";
    }
}

class InstallTessaDefaultConfigurationStep : Step
{
    [string] $TessaDistrib

    InstallTessaDefaultConfigurationStep([object] $json,[string] $tessaDistrib): base("Installing Tessa default configuration", $json, @([Role]::Web)){
        $this.TessaDistrib=$tessaDistrib
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        $tessaSetupFile="$($this.TessaDistrib)\Setup.bat";
        Start-Process -FilePath $tessaSetupFile -ArgumentList "/passive" -Wait
    
        Write-Host -ForegroundColor Gray "Restarting IIS";
        Execute-CommandWithExceptionOnErrorCode -CommandPath "iisreset"
    
        Write-Host -ForegroundColor Gray "Tessa default configuration installed";
    }
}

class CheckTessaWebServicesStep : Step
{
    CheckTessaWebServicesStep([object] $json): base("Checking Tessa Web Services working", $json, @([Role]::Web)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        #Ignore self-signed certificates error
        if (-not("dummy" -as [type])) {
        add-type -TypeDefinition @"
                    using System;
                    using System.Net;
                    using System.Net.Security;
                    using System.Security.Cryptography.X509Certificates;
                    
                    public static class Dummy {
                        public static bool ReturnTrue(object sender,
                            X509Certificate certificate,
                            X509Chain chain,
                            SslPolicyErrors sslPolicyErrors) { return true; }
                    
                        public static RemoteCertificateValidationCallback GetDelegate() {
                            return new RemoteCertificateValidationCallback(Dummy.ReturnTrue);
                        }
    
                        static Dummy(){
                            System.Net.ServicePointManager.ServerCertificateValidationCallback=GetDelegate();
                        }
                    }
"@
        }
        #      [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [dummy]::GetDelegate()
    
        $url="http://localhost/tessa/web/check"
        $Response = Invoke-WebRequest -URI $url
        if ($Response.Content.Contains("Error") -or !$Response.Content.Contains("ok")){
            Invoke-Expression "cmd.exe /C start $url"
            throw "Error checking Tessa web service on $url"
        }
    
        Write-Host -ForegroundColor Gray "Tessa Web Services work correctly";
    }
}


class InstallChronosStep : Step
{
    InstallChronosStep([object] $json): base("Installing Chronos", $json, @([Role]::Chronos)){}

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        Write-Host -ForegroundColor Gray "Installing Chronos $TessaVersion (using install-and-start.bat)";
        $chronosFolder =  $this.GetValueOrLogError("folder")
        $tessaChronosSetupFile="$chronosFolder\install-and-start.bat"
        Start-Process -FilePath $tessaChronosSetupFile -Wait
    
        $chonosServiceName="chronos"
        if (Get-Service $chonosServiceName -ErrorAction SilentlyContinue){
            Write-Host -ForegroundColor Gray "Chronos installed"
        } else {
            throw "Choronos service '$chonosServiceName' was not found"
        }
    }
}



class StartTessaAdminStep : Step
{
    [string] $TessaDistrib

    StartTessaAdminStep([object] $json,[string] $tessaDistrib): base("Starting TessaAdmin", $json, @([Role]::Web)){
        $this.TessaDistrib=$tessaDistrib
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        Start-Process -FilePath "$($this.TessaDistrib)\Applications\TessaAdmin\TessaAdmin.exe" -ArgumentList "/u:admin /p:admin"
        Write-Host -ForegroundColor Gray "TessaAdmin started"
    }
}

class StartTessaClientStep : Step
{
    [string] $TessaDistrib

    StartTessaClientStep([object] $json,[string] $tessaDistrib): base("Starting TessaClient", $json, @([Role]::Web)){
        $this.TessaDistrib=$tessaDistrib
    }

    [void] DoStep([Role[]] $ServerRoles, [Version] $TessaVersion){
        Start-Process -FilePath "$($this.TessaDistrib)\Applications\TessaClient\TessaClient.exe" -ArgumentList "/u:admin /p:admin"
        Write-Host -ForegroundColor Gray "TessaClient started"
    }
}


function Execute-Command
{
    [CmdletBinding()]
    param(
        [string]$CommandPath, 
        [string[]]$CommandArguments
    )
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $CommandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $CommandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    [pscustomobject]@{
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        exitCode = $p.ExitCode
    }
    $p.WaitForExit()
}

function Execute-CommandWithExceptionOnErrorCode{
    [CmdletBinding()]
    param(
        [string]$CommandPath, 
        [string[]]$CommandArguments
    )
    $result=Execute-Command -CommandPath $CommandPath -CommandArguments $CommandArguments
    if ($result.exitCode -ne 0){
        throw "Calling '$CommandPath' with arguments '$CommandArguments' returned exit code $($result.exitCode). Stderr: '$($result.stderr)'. Stdout: '$($result.stdout)'"
    }
    $result
}

function Execute-Tadmin{
    [CmdletBinding()]
    param(
        [string[]] $Arguments
    )
    Execute-CommandWithExceptionOnErrorCode -CommandPath $global:tadmin -CommandArguments $Arguments
}

function Install-TessaPrerequisites
{
    <#
        Установить пререквизиты (вещи, обязательные для установки Tessa, например, IIS для сервера приложений)
        .PARAMETER ServerRoles Роли сервера
        .PARAMETER TessaVersion Версия Тессы, пререквизиты к которой надо поставить
        .PARAMETER EnvironmentName Название окружения. При изменении конфигов возьмутся данные из JSON с соответствующим префиксом. Напирмер, "dev-pushin"
    #>
    [CmdletBinding()]
    param(
        [Role[]]
        $ServerRoles,
        
        [Version]
        $TessaVersion,
    
        [string]
        $EnvironmentName
    )

    Write-Verbose "Installing Tessa $TessaVersion with prerequisites for roles $( $ServerRoles|foreach { $_ } )"

    $json = Get-Content "$PSScriptRoot\config\install-settings.json" | Out-String | ConvertFrom-Json
    $commonRole = $json.roles.common
    $webRole = $json.roles.web
    $chronosRole = $json.roles.chronos
    $sqlRole = $json.roles.sql
    $tempFolder=$commonRole.paths.temp
    $tessaFolderInIis=$webRole.iis.'tessa-folder'
    $tessaDistribPath=$commonRole.paths.'tessa-distrib'
    $global:tadmin="$tessaDistribPath\Tools\tadmin.exe"
    $licenseFile=$commonRole.paths.license
    $soft=$commonRole.soft

    # Below are step numbers for Tessa 3.5.0 according to https://mytessa.ru/docs/InstallationGuide/InstallationGuide.html
    [Step[]]$steps = @()
    $steps += [NewKeyboardLayoutStep]::new($commonRole.'keyboard-layout') 
    $steps += [SetTimeZoneStep]::new($commonRole.'timezone')
    $steps += [InstallIisStep]::new($webRole.'iis')                                         # 3.1
    $steps += [NewSslCertificateStep]::new($webRole.'iis')                                  # 3.1
    $steps += [InstallCoreHostingRuntimeStep]::new($webRole.'core-runtime',$tempFolder)     # 3.1
    $steps += [AddUserToIusrsStep]::new($webRole.'iis')                                     # 3.2
    $steps += [CreateAppPool]::new($webRole.'iis')                                          # 3.3.1
    $steps += [CopyTessaWebStep]::new($webRole.'iis',$tessaDistribPath,$licenseFile)        # 3.3.4
    $steps += [ConvertFolderToWebApplicationStep]::new($webRole.'iis')                      # 3.3.5
    $steps += [RequireSslStep]::new($webRole.'iis')                                         # 3.3.6
    $steps += [EnableWinAuthStep]::new($webRole.'iis')                                      # 3.3.7
    $steps += [GenerateNewSecurityTokenStep]::new($webRole.'iis',$tessaDistribPath)                       # 3.4
    $steps += [ChangeAppJsonStep]::new($webRole.'iis',$EnvironmentName,"$tessaFolderInIis\app.json")      # 3.5
    $steps += [CopyChronosStep]::new($chronosRole,$tessaDistribPath,$licenseFile)                         # 3.6
    $steps += [ChangeAppJsonStep]::new($chronosRole,$EnvironmentName,"$($chronosRole.folder)\app.json")   # 3.6
    $steps += [AttachSqlIsoStep]::new($sqlRole)                                      
    $steps += [InstallSqlStep]::new($sqlRole)                                      
    $steps += [InstallSsmsStep]::new($sqlRole,$tempFolder)                                      
    $steps += [DetachSqlIsoStep]::new($sqlRole)                                      
    $steps += [DownloadAndInstallStep]::new($soft.'notepad-pp',$tempFolder,"Notepad++")                                      
    $steps += [DownloadAndInstallStep]::new($soft.'totalcmd',$tempFolder,"Total Commander")                                      
    $steps += [EnablePsRemotingStep]::new($commonRole.'psremoting')
    $steps += [ChangeAppJsonStep]::new($webRole,$EnvironmentName,"$tessaDistribPath\Tools\app.json")    # 3.7
    $steps += [InstallTessaDefaultConfigurationStep]::new($webRole,$tessaDistribPath)                   # 3.7
    $steps += [CheckTessaWebServicesStep]::new($webRole)                                                # 3.8
    $steps += [InstallChronosStep]::new($chronosRole)                                                   # 3.9
    $steps += [StartTessaAdminStep]::new($webRole,$tessaDistribPath)                                    # 3.10
    $steps += [StartTessaClientStep]::new($webRole,$tessaDistribPath)                                   # 3.10
    
    foreach ($step in $steps)
    {
        $step.DoAndLogStep($ServerRoles, $TessaVersion)
    }
}

Export-ModuleMember -Function Install-TessaPrerequisites