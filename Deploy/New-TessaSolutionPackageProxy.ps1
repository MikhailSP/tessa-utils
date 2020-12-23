param(
    [string] $SolutionPackage="c:\Upload\Tessa\Deploy\Package\MontTessaSolution.zip",
    [string] $TessaFolder="c:\Dev\tessa-3.5.0",
    [string] $User="admin",
    [string] $Password="admin",
    [string] $DeploySettings="deploy", 
    [switch] $Localizations,
    [switch] $Scheme,
    [switch] $Views,
    [switch] $Workplaces,
    [switch] $Types,
    [switch] $Cards,
    [switch] $TessaClient,
    [switch] $TessaServerExtensions,
    [switch] $TessaChronosExtensions
)

$OutputEncoding #Для создания консоли надо что-то в нее написать, иначе упадет дальше

$OutputEncoding = [Text.UTF8Encoding]::UTF8
$OutputEncoding=[Console]::OutputEncoding


Import-Module "$PSScriptRoot\Mont.Tessa.psm1" -Force
New-TessaSolutionPackage -SolutionPackage $SolutionPackage -TessaFolder $TessaFolder `
                        -User $User -Password $Password -DeploySettings $DeploySettings `
                        -Localizations:$Localizations -Scheme:$Scheme -Views:$Views -Workplaces:$Workplaces `
                        -Types:$Types -Cards:$Cards -TessaClient:$TessaClient `
                        -TessaServerExtensions:$TessaServerExtensions `
                        -TessaChronosExtensions:$TessaChronosExtensions -Verbose