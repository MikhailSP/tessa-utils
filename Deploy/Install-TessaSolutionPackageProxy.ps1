[CmdletBinding()]
param(
    [string] $SolutionPackage="c:\Upload\Tessa\Deploy\Package\MontTessaSolution.zip",
    [string] $MachineToDeploy="TESSA-DEV",
    [string] $User="admin",
    [string] $Password="admin",
    [string] $LocalizationsStr,
    [string] $SchemeStr,
    [string] $ViewsStr,
    [string] $WorkplacesStr,
    [string] $TypesStr,
    [string] $CardsStr,
    [string] $TessaClientStr,
    [string] $TessaServerExtensionsStr,
    [string] $TessaChronosExtensionsStr,
    [string] $NoAutoCleanStr
)

#$OutputEncoding #Для создания консоли надо что-то в нее написать, иначе упадет дальше
#$OutputEncoding = [Text.UTF8Encoding]::UTF8
#$OutputEncoding=[Console]::OutputEncoding

Import-Module "$PSScriptRoot\MikhailSP.Tessa.Deploy.psm1" -Force

$localizations=ConvertTo-BooleanTfsValue -Name "LocalizationsStr" -StringValue $LocalizationsStr -Verbose
$scheme=ConvertTo-BooleanTfsValue -Name "SchemeStr" -StringValue $SchemeStr -Verbose
$views=ConvertTo-BooleanTfsValue -Name "ViewsStr" -StringValue $ViewsStr -Verbose
$workplaces=ConvertTo-BooleanTfsValue -Name "WorkplacesStr" -StringValue $WorkplacesStr -Verbose
$types=ConvertTo-BooleanTfsValue -Name "TypesStr" -StringValue $TypesStr -Verbose
$cards=ConvertTo-BooleanTfsValue -Name "CardsStr" -StringValue $CardsStr -Verbose
$tessaClient=ConvertTo-BooleanTfsValue -Name "TessaClientStr" -StringValue $TessaClientStr -Verbose
$tessaServerExtensions=ConvertTo-BooleanTfsValue -Name "TessaServerExtensionsStr" -StringValue $TessaServerExtensionsStr -Verbose
$tessaChronosExtensions=ConvertTo-BooleanTfsValue -Name "TessaChronosExtensionsStr" -StringValue $TessaChronosExtensionsStr -Verbose
$noAutoClean=ConvertTo-BooleanTfsValue -Name "NoAutoCleanStr" -StringValue $NoAutoCleanStr -Verbose


$machine = $MachineToDeploy.ToLower();
if ($machine.IndexOf(".") -ge 1){
    $machine=$machine.Substring(0,$machine.IndexOf("."));
}
Write-Verbose "Выбран конфиг для машины $machine"

$jsonContent = Get-Content "$PSScriptRoot\Environments\environments.json" | ConvertFrom-Json
$environment = $jsonContent.defaults
Merge-Jsons -source $jsonContent.$machine -target $environment

$TessaPoolName = $environment.server."pool-name"
Write-Verbose "TessaPoolName = '$TessaPoolName'"

$TessaServerUrl = $environment.server."url"
Write-Verbose "TessaServerUrl = '$TessaServerUrl'"

$TessaChronosServiceName = $environment.chronos."service-name"
Write-Verbose "TessaChronosServiceName = '$TessaChronosServiceName'"

Install-TessaSolutionPackage -SolutionPackage $SolutionPackage `
                        -TessaServerUrl $TessaServerUrl `
                        -TessaChronosServiceName $TessaChronosServiceName `
                        -User $User -Password $Password `
                        -Localizations:$localizations -Scheme:$scheme -Views:$Views `
                        -Workplaces:$workplaces -Types:$types -Cards:$cards `
                        -TessaClient:$tessaClient -TessaServerExtensions:$tessaServerExtensions `
                        -TessaChronosExtensions:$tessaChronosExtensions -NoAutoClean:$noAutoClean -Verbose