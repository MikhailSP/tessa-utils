$OutputEncoding #Для создания консоли надо что-то в нее написать, иначе упадет дальше
$OutputEncoding = [Text.UTF8Encoding]::UTF8
$OutputEncoding=[Console]::OutputEncoding


Import-Module "$PSScriptRoot\MikhailSP.Tessa.Utils.psm1" -Force -Verbose
Install-TessaPrerequisites -ServerRoles Web,Sql -TessaVersion v3_5_0 -Verbose