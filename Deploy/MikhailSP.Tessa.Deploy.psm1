$DefaultTessaDistribFolder='c:\Dev\tessa-3.5.0'
$DefaultTessaPackageFolder="c:\Upload\Tessa\Deploy\Package"
$TessaGitRoot="$PSScriptRoot\..\.."
$TessaDeployJsonPath="$PSScriptRoot\Config"
$DefaultTessaDeployJson="deploy.json"
$TempFolder="c:\temp"

$TessaPackageLocalizationsPartPath="model\localizations"
$TessaPackageSchemePartPath="model\scheme"
$TessaPackageViewsPartPath="model\views"
$TessaPackageWorkplacesPartPath="model\workplaces"
$TessaPackageCardsPartPath="model\cards"
$TessaPackageTypesPartPath="model\types"
$TessaPackageTypesCardsPartPath="model\types\Cards"
$TessaPackageTypesFilesPartPath="model\types\Files"
$TessaPackageTypesTasksPartPath="model\types\Tasks"
$TessaPackageClientPartPath="code\client"
$TessaPackageServerPartPath="code\server"
$TessaPackageChronosPartPath="code\chronos"
$ConfigurationWellKnownSubparts=@(
    "Cards\Access rules",
    "Cards\Currencies",
    "Cards\Document types",
    "Cards\File templates",
    "Cards\KrProcess",
    "Cards\Notifications",
    "Cards\PostgreSql",
    "Cards\Report permissions",
    "Cards\Roles\Context",
    "Cards\Roles\Static",
    "Cards\Roles",
    "Cards\Settings",
    "Cards\Task history group types",
    "Types\Cards\_WithoutGroup",
    "Types\Cards\Dictionaries",
    "Types\Cards\Documents",
    "Types\Cards\KrProcess",
    "Types\Cards\Permissions",
    "Types\Cards\Roles",
    "Types\Cards\Routes",
    "Types\Cards\Settings",
    "Types\Cards\System",
    "Types\Cards\UserSettings",
    "Types\Cards\Wf",
    "Types\Cards\WorkflowActions",
    "Types\Cards\WorkflowEngine",
    "Types\Cards\Архив",
    "Types\Cards\Договорные документы",
    "Types\Cards\Регулярные платежи",
    "Types\Cards\Справочники Монт",
    "Types\Cards",
    "Types\Files",
    "Types\Tasks"
)
$CardsDeployOrder=@(
    "Document types",
    "Roles\Context",
    "Roles\Static",
    "Roles",
    "Access rules",
    "Currencies",
    "File templates",
    "KrProcess",
    "Notifications",
    "PostgreSql",
    "Report permissions",
    "Settings",
    "Task history group types"
)

$TadminPath="Tools\tadmin.exe"
$TessaClientRelativeFolder="Applications\TessaClient"
$TessaClientPath="$TessaClientRelativeFolder\TessaClient.exe"
$TessaAdminPath="Applications\TessaAdmin\TessaAdmin.exe"
$FileToBeSureCorrectTessaServerFolder="Tessa.Extensions.Server.dll"
$FileToBeSureCorrectTessaChronosFolder="Chronos.exe"
$FileToBeSureCorrectTessaClientFolder="TessaClient.exe"

function Test-TessaExitCode{
    param(
        [int] $ExitCode,
        [string] $ActionTitle
    )
    
    if ($ExitCode -eq 0){
        Write-Information "$ActionTitle :`t OK"
    } else {
        Write-Error "$ActionTitle :`t Ошибка. Код: $ExitCode"
        exit -1
    }     
}

function New-EmptyFolder{
    <#
        .SYNOPSIS
            Создание чистой папки (создание - если нет, очистка - если существует)
    #>
    [CmdletBinding()]
    param(
        [string] $FolderPath,
        [string] $FolderDescrition="Временная"
    )

    if (!$FolderPath){
        Write-Error "Не указана папка для создания"
        exit -1
    }
    
    if (Test-Path $FolderPath){
        Write-Verbose "Очистка папки '$FolderDescrition' '$FolderPath'"
        Remove-Item –Path "$FolderPath\*" –Recurse -Force
    } else {
        Write-Verbose "Создание папки '$FolderDescrition' '$FolderPath'"
        New-Item -ItemType Directory -Force -Path $FolderPath > $null # Без нулл - пишет в Output и портит возврат $tempFolder
    }
}

function Start-TessaApplicationAndTestResult{
    param(
        [string] $ApplicationFile="",
        [string] $ArgumentList="",
        [string] $ActionTitle
    )

    Write-Verbose "Запуск '$ApplicationFile' с параметрами '$ArgumentList'"
    $process = Start-Process $ApplicationFile -ArgumentList $ArgumentList -Wait -ErrorVariable $err -NoNewWindow -PassThru
    Test-TessaExitCode -ExitCode $process.ExitCode -ActionTitle $ActionTitle
}

function Start-Tadmin{
    param(
        [string] $TessaFolder=$DefaultTessaDistribFolder,
        [string] $ArgumentList="",
        [string] $ActionTitle
    )

    $tadmin=Join-Path -Path $TessaFolder -ChildPath $TadminPath
    Start-TessaApplicationAndTestResult -ApplicationFile $tadmin  -ArgumentList $ArgumentList -ActionTitle $ActionTitle
}

function Start-TessaClient{
    param(
        [string] $TessaFolder=$DefaultTessaDistribFolder,
        [string] $ArgumentList="",
        [string] $ActionTitle
    )

    $tessaClient=Join-Path -Path $TessaFolder -ChildPath $TessaClientPath
    Start-TessaApplicationAndTestResult -ApplicationFile $tessaClient  -ArgumentList $ArgumentList -ActionTitle $ActionTitle
}

function Start-TessaAdmin{
    param(
        [string] $TessaFolder=$DefaultTessaDistribFolder,
        [string] $ArgumentList="",
        [string] $ActionTitle
    )

    $tessaAdmin=Join-Path -Path $TessaFolder -ChildPath $TessaAdminPath
    Start-TessaApplicationAndTestResult -ApplicationFile $tessaAdmin  -ArgumentList $ArgumentList -ActionTitle $ActionTitle
}

function Merge-Jsons ($target, $source) {
    if ($source -eq $Null) {
        return
    }
    $source.psobject.Properties | % {
        if ($_.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject' -and $target."$($_.Name)" ) {
            Merge-Jsons $target."$($_.Name)" $_.Value
        }
        else {
            $target | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value -Force
        }
    }
}

function Read-TessaDeploySectionFromJson{
    param(
        [string] $DeploySettings,
        [string] $Section,
        [string] $Subsection
    )

    $jsonFile = Join-Path -Path $TessaDeployJsonPath -ChildPath $DefaultTessaDeployJson
    if (($DeploySettings -ne $null) -and ($DeploySettings -ne "")){
        $jsonFile = Join-Path -Path $TessaDeployJsonPath -ChildPath "$DeploySettings.json"
    }
    
    $jsonContent = Get-Content $jsonFile | ConvertFrom-Json
    if ($jsonContent.parent -ne $null){
        $parentJson = Join-Path -Path $TessaDeployJsonPath -ChildPath $jsonContent.parent
        $parentJsonContent = Get-Content $parentJson | ConvertFrom-Json
        Merge-Jsons -source $jsonContent -target $parentJsonContent
        $jsonContent = $parentJsonContent
        # $jsonContent = @($parentJsonContent; $jsonContent)
    }
    if ($Subsection){
        $jsonContent.$Section.$Subsection | where{($_ -notlike "//*") -and ($_ -ne $null)}
    } else {
        $jsonContent.$Section | where{($_ -notlike "//*") -and ($_ -ne $null)}
    }
}

function Merge-TessaClientWithExtensions{
    [CmdletBinding()]
    param(
        [string] $TessaFolder=$DefaultTessaDistribFolder,
        [string] $TargetFolder="$DefaultTessaPackageFolder\Code\TessaClient",
        [string] $DeploySettings
    )

    Write-Verbose "Подготовка TessaClient для публикации в '$TargetFolder'"

    $tempFolder="$TempFolder\client\"
    $tessaClient=Join-Path -Path $TessaFolder -ChildPath $TessaClientPath
    $tessaClientFolder=Split-Path -Path $tessaClient

    New-EmptyFolder -FolderPath $tempFolder -FolderDescrition "Временная для TessaClient" -Verbose

    # Сейчас дистрибутив собирается с таргет-сервера, т.к. нужен актуальный app.json
    # Write-Verbose "Копирование TessaClient во временную папку из дистрибутива '$tessaClientFolder'"
    # Copy-Item -Path "$tessaClientFolder\*" -Destination $tempFolder -Recurse -Force

    Write-Verbose "Копирование файлов расширений клиента во временный TessaClient"
    $filesToCopy=Read-TessaDeploySectionFromJson -DeploySettings $DeploySettings -Section "client"
    foreach($fileToCopy in $filesToCopy){
        Copy-Item -Path "$TessaGitRoot\$fileToCopy" -Destination $tempFolder -Recurse -Force -Verbose
    }

    Write-Verbose "Создание папки TessaClient '$TargetFolder' в пакете деплоя"
    New-Item -ItemType Directory -Force -Path $TargetFolder

    Write-Verbose "Перенос содержимого временной папки TessaClient в '$TargetFolder'"
    Move-Item -Path "$tempFolder\*" -Destination "$TargetFolder" -Force
}

function Copy-TessaServerExtensionsPart{
    <#
        .SYNOPSIS
            Копирование серверных расширений Тесса
    #>
    [CmdletBinding()]
    param(
        [string] $TargetFolder="$DefaultTessaPackageFolder\Code\TessaServer",
        [string] $DeploySettings
    )

    Write-Verbose "Подготовка TessaServerExtensions для публикации в '$TargetFolder'"
    
    New-EmptyFolder -FolderPath $TargetFolder -FolderDescrition "Серверные расширения Tessa" -Verbose
    
    Write-Verbose "Копирование файлов серверных расширений"
    $filesToCopy=Read-TessaDeploySectionFromJson -DeploySettings $DeploySettings -Section "server"
    foreach($fileToCopy in $filesToCopy){
        Copy-Item -Path "$TessaGitRoot\$fileToCopy" -Destination $TargetFolder -Recurse -Force -Verbose
    }
}

function Copy-TessaChronosExtensionsPart{
    <#
        .SYNOPSIS
            Копирование расширений Chronos Тесса
    #>
    [CmdletBinding()]
    param(
        [string] $TargetFolder="$DefaultTessaPackageFolder\Code\Chronos",
        [string] $DeploySettings
    )

    Write-Verbose "Подготовка TessaServerExtensions для публикации в '$TargetFolder'"
    
    New-EmptyFolder -FolderPath $TargetFolder -FolderDescrition "Расширения Chronos Tessa" -Verbose
    
    Write-Verbose "Копирование файлов расширений Chronos"
    $filesToCopy=Read-TessaDeploySectionFromJson -DeploySettings $DeploySettings -Section "chronos"
    foreach($fileToCopy in $filesToCopy){
        if ($fileToCopy.Contains("\configuration\")){
            New-Item -ItemType Directory -Force -Path "$TargetFolder\configuration"
            Copy-Item -Path "$TessaGitRoot\$fileToCopy" -Destination "$TargetFolder\configuration" -Recurse -Force -Verbose
        } else {
            Copy-Item -Path "$TessaGitRoot\$fileToCopy" -Destination $TargetFolder -Recurse -Force -Verbose
        }
    }
}

function Copy-TessaSolutionPart{
    <#
        .SYNOPSIS
            Копирование части решения Тесса (схема, карточки, представления, рабочие места, код решений)
    #>
    [CmdletBinding()]
    param(
        [string] $SolutionPackageFolder,
        [string] $SolutionPartRelativeFolder,
        [string] $ModelFolder="f:\Upload\Tessa\temp\ExportedSolution",
        [string] $DeploySectionSubsection,
        [string] $DeploySettings
    )
    if (Test-Path $ModelFolder){
        $solutionPartTargetFolder=Join-Path -Path $SolutionPackageFolder -ChildPath $SolutionPartRelativeFolder
        Write-Verbose "Копирование данных из секции $DeploySectionSubsection в $solutionPartTargetFolder"


        New-EmptyFolder -FolderPath $solutionPartTargetFolder -FolderDescrition "Целевая для модели ($DeploySectionSubsection)" -Verbose

        $filesToCopy=Read-TessaDeploySectionFromJson -DeploySettings $DeploySettings -Section "package" -Subsection $DeploySectionSubsection
        foreach($fileToCopy in $filesToCopy){
            
            $targetPath=$solutionPartTargetFolder
            foreach($knownPart in $ConfigurationWellKnownSubparts){
                if ($fileToCopy.ToLower().StartsWith($knownPart.ToLower())){
                    $knownPartWithoutType=$knownPart.Substring($knownPart.IndexOf("\")+1)
                    $targetPath=Join-Path -Path $solutionPartTargetFolder -ChildPath $knownPartWithoutType
                    break
                }
            }
            if (!(Test-Path $targetPath)) {
                New-EmptyFolder -FolderPath $targetPath -FolderDescrition "Целевая для модели ($DeploySectionSubsection)" -Verbose
            }
            Copy-Item -Path "$ModelFolder\$fileToCopy" -Destination $targetPath -Recurse -Force -Verbose
        }
    } else {
        Write-Error "Папка модели '$ModelFolder' не найдена"
        exit -1
    }
}

function New-TessaSolutionPackage{
    <#
        .SYNOPSIS
            Подготовка архива, содержащего готовое к деплою решение Тесса (схема, карточки, представления, рабочие места, код решений)
    #>
    [CmdletBinding()]
    param(
        [string] $SolutionPackage="$DefaultTessaPackageFolder\MontTessaSolution.zip",
        [string] $TessaFolder=$DefaultTessaDistribFolder,
        [string] $ModelFolder="$TessaGitRoot\Configuration",
        [string] $User="admin",
        [string] $Password="admin",
        [string] $DeploySettings,
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

    $tempFolder="$TempFolder\TessaPreparePackage";

    New-EmptyFolder -FolderPath $tempFolder -FolderDescrition "Временная для пакета деплоя" -Verbose

    $all=!$Localizations -and !$Scheme -and !$Views -and !$Workplaces -and !$Types `
                -and !$Cards -and !$TessaClient -and !$TessaServerExtensions -and !$TessaChronosExtensions
    if ($all){
        Write-Verbose "Не указаны компоненты для пакета деплоя - включаем все компоненты"
    }

    if ($Scheme -or $all){
        Copy-TessaSolutionPart -SolutionPackageFolder $tempFolder -ModelFolder $ModelFolder `
                                -SolutionPartRelativeFolder $TessaPackageSchemePartPath `
                                -DeploySectionSubsection "scheme" -DeploySettings $DeploySettings -Verbose
    }
    if ($Localizations -or $all){
        Copy-TessaSolutionPart -SolutionPackageFolder $tempFolder -ModelFolder $ModelFolder `
        -SolutionPartRelativeFolder $TessaPackageLocalizationsPartPath `
        -DeploySectionSubsection "localizations" -DeploySettings $DeploySettings -Verbose
    }
    if ($Types -or $all){
        Copy-TessaSolutionPart -SolutionPackageFolder $tempFolder -ModelFolder $ModelFolder `
                                -SolutionPartRelativeFolder $TessaPackageTypesPartPath `
                                -DeploySectionSubsection "types" -DeploySettings $DeploySettings -Verbose
    }
    if($Cards -or $all){
        Copy-TessaSolutionPart -SolutionPackageFolder $tempFolder -ModelFolder $ModelFolder `
                                -SolutionPartRelativeFolder $TessaPackageCardsPartPath `
                                -DeploySectionSubsection "cards" -DeploySettings $DeploySettings -Verbose
    }
    if ($Views -or $all){
        Copy-TessaSolutionPart -SolutionPackageFolder $tempFolder -ModelFolder $ModelFolder `
                                -SolutionPartRelativeFolder $TessaPackageViewsPartPath `
                                -DeploySectionSubsection "views" -DeploySettings $DeploySettings -Verbose
    }
    if ($Workplaces -or $all){
        Copy-TessaSolutionPart -SolutionPackageFolder $tempFolder -ModelFolder $ModelFolder `
                                -SolutionPartRelativeFolder $TessaPackageWorkplacesPartPath `
                                -DeploySectionSubsection "workplaces" -DeploySettings $DeploySettings -Verbose
    }

    
    if ($TessaClient -or $all){
        $tessaClientTargetFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageClientPartPath
        Merge-TessaClientWithExtensions -DeploySettings $DeploySettings -TessaFolder $TessaFolder -TargetFolder $tessaClientTargetFolder -Verbose
    }
    
    if ($TessaServerExtensions -or $all){
        $tessaServerTargetFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageServerPartPath
        Copy-TessaServerExtensionsPart -DeploySettings $DeploySettings -TargetFolder $tessaServerTargetFolder
    }    
    
    if ($TessaChronosExtensions -or $all){
        $tessaChronosTargetFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageChronosPartPath
        Copy-TessaChronosExtensionsPart -DeploySettings $DeploySettings -TargetFolder $tessaChronosTargetFolder
    }
    
    if (Test-Path $SolutionPackage){
        Write-Verbose "Удаление старого пакета '$SolutionPackage'"
        Remove-Item -Path $SolutionPackage -Force
    } else {
        $packageFolder = Split-Path -Path $SolutionPackage -Parent
        Write-Verbose "Создание папки '$packageFolder' для пакета"
        New-Item -ItemType Directory -Force -Path $packageFolder
    }
    Write-Verbose "Создание архива $SolutionPackage"
    Compress-Archive -Path "$tempFolder\*" -DestinationPath $SolutionPackage

    Write-Verbose "Удаление временной папки '$tempFolder'"
    Remove-Item $tempFolder -Recurse -Force
}

function Install-TessaSolutionPackage {
    <#
        .SYNOPSIS
            Установка решения Тесса (импорт схемы, карточек, представлений, рабочих мест, кода решений)
    #>
    [CmdletBinding()]
    param(
        [string] $SolutionPackage="$DefaultTessaPackageFolder\MontTessaSolution.zip",
        [string] $TessaFolder=$DefaultTessaDistribFolder,
        [string] $TessaServerFolder="c:\inetpub\wwwroot\tessa\web",
        [string] $TessaServerUrl="https://localhost/tessa",
        [string] $TessaChronosFolder="c:\Tessa\Chronos",
        [string] $TessaPoolName="TessaPool",
        [string] $TessaChronosServiceName="Syntellect Chronos",
        [string] $User="admin",
        [string] $Password="admin",
        [switch] $Localizations,
        [switch] $Scheme,
        [switch] $Views,
        [switch] $Workplaces,
        [switch] $Types,
        [switch] $Cards,
        [switch] $TessaClient,
        [switch] $TessaServerExtensions,
        [switch] $TessaChronosExtensions,
        [switch] $NoAutoClean
    )
    
    $tempFolder="$TempFolder\TessaDeployPackage";

    New-EmptyFolder -FolderPath $tempFolder -FolderDescrition "Временная для пакета деплоя" -Verbose

    Write-Verbose "Распаковка архива '$SolutionPackage' в папку '$tempFolder'"
    Expand-Archive -Path $SolutionPackage -DestinationPath $tempFolder
    
    $localizationsFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageLocalizationsPartPath
    $schemesFile=Join-Path -Path $tempFolder -ChildPath $TessaPackageSchemePartPath
    $viewsFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageViewsPartPath
    $workplacesFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageWorkplacesPartPath
    $typesFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageTypesPartPath
    $cardTypesFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageTypesCardsPartPath
    $fileTypesFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageTypesFilesPartPath
    $taskTypesFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageTypesTasksPartPath
    $cardsFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageCardsPartPath
    $tessaClientPublishFolder=Join-Path -Path $tempFolder -ChildPath $TessaPackageClientPartPath
    
    $credentialsArg="/u:$User /p:$Password /a:$TessaServerUrl"
    
    $all=!$Scheme -and !$Views -and !$Workplaces -and !$Types -and !$Cards `
                   -and !$TessaClient -and !$TessaServerExtensions -and !$TessaChronosExtensions
    if ($all){
        Write-Verbose "Не указаны компоненты для пакета деплоя - деплоим все компоненты"
    }
    
    if ($all -or $Localizations){
        Write-Verbose "Деплоим локализации"
        if (Test-Path -Path "$localizationsFolder\*"){
            Start-Tadmin -TessaFolder $TessaFolder -ArgumentList "ImportLocalization $localizationsFolder $credentialsArg" -ActionTitle "Импорт локализаций"
        } else {
            Write-Verbose "Нет файлов локализации. Пропускаем шаг."
        }
    }    
    if ($all -or $Scheme){
        Write-Verbose "Деплоим схему"
        Start-Tadmin -TessaFolder $TessaFolder -ArgumentList "ImportScheme $schemesFile $credentialsArg" -ActionTitle "Импорт схемы"
    }
    if ($all -or $Views){
        Write-Verbose "Деплоим представления"
        Start-Tadmin -TessaFolder $TessaFolder -ArgumentList "ImportViews $viewsFolder $credentialsArg" -ActionTitle "Импорт представлений"
    }
    if ($all -or $Workplaces){
        Write-Verbose "Деплоим рабочие места"
        Start-Tadmin -TessaFolder $TessaFolder -ArgumentList "ImportWorkplaces $workplacesFolder $credentialsArg" -ActionTitle "Импорт рабочих мест"
    }
    if ($all -or $Types){
        Write-Verbose "Деплоим типы (карточки)"
        $cardDirs=Get-ChildItem -Path $cardTypesFolder -Directory
        if ($cardDirs -eq '') {
            Write-Verbose "Деплой типов (карточек). Пропускаем. Нет подпапок. Возможно забыли добавить их в Mont.Tessa.psm1 в массив ConfigurationWellKnownSubparts"
        }
        foreach($cardDir in $cardDirs){
            Write-Verbose "Деплоим типы (карточки) группы '$($cardDir.Name)'"
            Start-Tadmin -TessaFolder $TessaFolder -ArgumentList "ImportTypes `"$($cardDir.FullName)`" $credentialsArg" -ActionTitle "Импорт типов (карточек) группы '$($cardDir.Name)'"
        }
    }
    if ($all -or $Cards){
        Write-Verbose "Деплоим карточки (контент). Уже существующие карточки будут проигнорированы (ключ /e)"

        foreach($cardsSubfolder in $CardsDeployOrder){
            $cardsSubfolderPath=Join-Path -Path $cardsFolder -ChildPath $cardsSubfolder
            if (!(Test-Path $cardsSubfolderPath)){
                continue;
            }
            $numberOfFiles = (Get-ChildItem -Path $cardsSubfolderPath -File).Length
            $cardsPath = [System.IO.DirectoryInfo]$cardsSubfolderPath
            if ($numberOfFiles -eq 0){
                Write-Verbose "Пропускаем карточки (контент) группы '$($cardsPath.Name)', т.к. нет файлов"
                continue
            }
            Write-Verbose "Деплоим карточки (контент) группы '$($cardsPath.Name)' ($numberOfFiles)"
            Start-Tadmin -TessaFolder $TessaFolder -ArgumentList "ImportCards `"$($cardsPath.FullName)`" $credentialsArg /e" -ActionTitle "Импорт карточек группы '$($cardsPath.Name)'"
        }
    }
    if ($all -or $TessaClient)
    {
        $tessaClientDistribFolder = Join-Path -Path $TessaFolder -ChildPath $TessaClientRelativeFolder
        $fileShouldExistIfClient=Join-Path -Path $tessaClientDistribFolder -ChildPath $FileToBeSureCorrectTessaClientFolder
        if (!(Test-Path $fileShouldExistIfClient)){
            Write-Error "Некорректная папка дистрибутива TessaClient '$tessaClientDistribFolder'"
            exit -1
        }
        Write-Verbose "Папка дистрибутива TessaClient указана корректно"
        $tessaClientTempFolder = Join-Path -Path $tempFolder -ChildPath "TessaClient"
        New-Item -ItemType Directory -Force -Path $tessaClientTempFolder
        
        Write-Verbose "Копируем дистрибутив TessaClient во временную папку"
        Copy-Item -Path "$tessaClientDistribFolder\*" -Destination $tessaClientTempFolder -Recurse
        
        Write-Verbose "Копируем кастомизации TessaClient во временную папку"
        Copy-Item -Path "$tessaClientPublishFolder\*" -Destination $tessaClientTempFolder -Recurse
        
        $tessaClientWithExtensionsFile = Join-Path -Path $tessaClientTempFolder -ChildPath "TessaClient.exe"
        Write-Verbose "Публикуем TessaClient"
        
        Start-TessaApplicationAndTestResult -ApplicationFile $tessaClientWithExtensionsFile `
                                        -ArgumentList "/publish $credentialsArg" `
                                        -ActionTitle "Публикация клиента" -Verbose
    }
    
    if ($all -or $TessaServerExtensions){
        $fileShouldExistIfServer=Join-Path -Path $TessaServerFolder -ChildPath $FileToBeSureCorrectTessaServerFolder
        if (!(Test-Path $fileShouldExistIfServer)){
            Write-Error "Некорректная папка сервера '$TessaServerFolder'"
            exit -1
        }
        Write-Verbose "Папка сервера указана корректно"

        Import-Module WebAdministration -Force

        Write-Verbose "Останавливаем пул '$TessaPoolName' для копирования файлов"
        Stop-WebAppPool -Name $TessaPoolName -Passthru
        
        $waitCounter=0;
        do
        {
            Start-Sleep -Milliseconds 1000
            $waitCounter=$waitCounter+1
            if ($waitCounter -ge 30)
            {
                Write-Error "Не получилось остановить '$TessaPoolName'"
                exit -1
            }
            $poolState=(Get-WebAppPoolState -Name $TessaPoolName).Value
        } while ($poolState -ne "Stopped")
        Write-Verbose "Пул '$TessaPoolName' успешно остановлен"
        Copy-Item -Path "$tempFolder\$TessaPackageServerPartPath\*" -Destination "$TessaServerFolder" -Force
        Start-WebAppPool -Name $TessaPoolName -Passthru
        Write-Verbose "Запускаем пул '$TessaPoolName' после копирования файлов"
    }
    
    if ($all -or $TessaChronosExtensions){
        $fileShouldExistIfServer=Join-Path -Path $TessaChronosFolder -ChildPath $FileToBeSureCorrectTessaChronosFolder
        if (!(Test-Path $fileShouldExistIfServer)){
            Write-Error "Некорректная папка Chronos '$TessaChronosFolder'"
            exit -1
        }
        Write-Verbose "Папка Chronos указана корректно"

        Write-Verbose "Останавливаем сервис '$TessaChronosServiceName' для копирования файлов"
        Stop-Service -Name $TessaChronosServiceName

        Copy-Item -Path "$tempFolder\$TessaPackageServerPartPath\*" -Destination "$TessaChronosFolder\extensions" -Force
        Copy-Item -Path "$tempFolder\$TessaPackageChronosPartPath\*" -Destination "$TessaChronosFolder\Plugins\Tessa.Extensions.Chronos" -Force
        
        Write-Verbose "Запускаем сервис '$TessaChronosServiceName' после копирования файлов"
        Start-Service -Name $TessaChronosServiceName
    }
    
    if (!$NoAutoClean){
        Write-Verbose "Удаляем временную папку '$tempFolder'"
        Remove-Item -Path $tempFolder -Force -Recurse
    }
}


function ConvertTo-BooleanTfsValue(){
    [CmdletBinding()]
    param(
        [string] $Name,
        [string] $StringValue
    )
    if ($null -eq $StringValue){
        Write-Verbose "Параметр $Name не указан, берем за false"
        $false
    }
    else
    {
        $boolValue=($StringValue -eq "true") -or ($StringValue -eq "1")
        Write-Verbose "Параметр $Name = $StringValue, берем за $boolValue"
        $boolValue
    }
}


Export-ModuleMember -Function New-TessaSolutionPackage
Export-ModuleMember -Function Install-TessaSolutionPackage
Export-ModuleMember -Function ConvertTo-BooleanTfsValue
Export-ModuleMember -Function Merge-Jsons
