$DefaultPartitionName="Default"

function Get-PhysicalColumnObject{
    [CmdletBinding()]
    param(
        $PhysicalColumn
    )
    $column=@{}
    $column.id=$PhysicalColumn.ID
    $column.name=$PhysicalColumn.Name
    $column.description=$PhysicalColumn.Description
    $column.type=$PhysicalColumn.Type
    $column.category='Physical'
    $column.system=$PhysicalColumn.IsSystem
    $column.permanent=$PhysicalColumn.IsPermanent
    $column.sealed=$PhysicalColumn.IsSealed
    $column.partitionId=$PhysicalColumn.Partition
    $column
}

function Get-ReferencingColumnObject{
    [CmdletBinding()]
    param(
        $RefColumn
    )
    $column=@{}
    $column.id=$RefColumn.ID
    $column.name=$RefColumn.Name
    $column.type=$RefColumn.Type
    $column.category='Complex'
    $column.columnId=$RefColumn.ReferencedColumn
    $column.partitionId=$RefColumn.Partition
    $column
}

function Get-ReferencingColumnRootObject{
    [CmdletBinding()]
    param(
        $ComplexColumn
    )
    $column=@{}
    $column.id=$ComplexColumn.ID
    $column.name=$ComplexColumn.Name
    $column.type=$ComplexColumn.Type
    $column.category='ComplexRoot'
    $column.tableId=$ComplexColumn.ReferencedTable
    $column.partitionId=$ComplexColumn.Partition
    $column
}


function Get-TessaTableObject{
    [CmdletBinding()]
    param(
        [string] $TstFile,
        [switch] $GenerateRecords
    )
    [xml] $tstXml = Get-Content -Path $TstFile
    $table=@{}
    $table.id = $tstXml.SchemeTable.ID
    $table.partitionId = $tstXml.SchemeTable.Partition
    $table.instanceType = $tstXml.SchemeTable.InstanceType
    $table.contentType = $tstXml.SchemeTable.ContentType
    $table.name = $tstXml.SchemeTable.Attributes["Name"].'#text' #Так хитро, т.к. просто Name возвращает SchemeTable, если нет аттрибута
    $table.description = $tstXml.SchemeTable.Description
    $table.group = $tstXml.SchemeTable.Group
    $table.columns=@()
    $table.records=@()

    foreach ($physicalColumn in $tstXml.SchemeTable.SchemePhysicalColumn)
    {
        $table.columns+=Get-PhysicalColumnObject -PhysicalColumn $physicalColumn
    }

    foreach ($complexColumn in $tstXml.SchemeTable.SchemeComplexColumn)
    {
        $table.columns+=Get-ReferencingColumnRootObject -ComplexColumn $complexColumn
        foreach ($refColumn in $complexColumn.SchemeReferencingColumn){
            $column=Get-ReferencingColumnObject -RefColumn $refColumn
            $column.description=$complexColumn.Description
            $column.tableId=$complexColumn.ReferencedTable
            $column.system=$complexColumn.IsSystem
            $column.permanent=$complexColumn.IsPermanent
            $column.sealed=$complexColumn.IsSealed
            $table.columns+=$column
        }
        foreach ($physicalColumn in $complexColumn.SchemePhysicalColumn){
            $column=Get-PhysicalColumnObject -PhysicalColumn $physicalColumn
            $column.description=$complexColumn.Description
            $column.tableId=$complexColumn.ReferencedTable
            $column.system=$complexColumn.IsSystem
            $column.permanent=$complexColumn.IsPermanent
            $column.sealed=$complexColumn.IsSealed
            $table.columns+=$column
        }
    }
    
    if ($GenerateRecords)
    {
        foreach ($schemeRecord in $tstXml.SchemeTable.SchemeRecord)
        {
            $record = @{ }
            $record.values = @{ }
            $record.partitionId = $schemeRecord.Partition
            foreach ($node in $schemeRecord.ChildNodes)
            {
                $record.values[$node.Name] = $node."#text"
            }
            $table.records += $record
        }
    }
    return $table;
}




function Add-TessaTableToObject
{
    [CmdletBinding()]
    param(
        $TessaScheme,
        [string] $TstFile,
        [string] $SubPackage,
        [ValidateSet('Scheme', 'Partition')][string] $Type,
        [switch] $GenerateEnums,
        [switch] $GenerateClasses,
        [switch] $GenerateLinks,
        [switch] $GenerateRecords
    )

    if (!(Test-Path -Path $TstFile)){
        Write-Error "Incorrect path to .tst file: $TstFile"
        return
    }

    $tessaTable = Get-TessaTableObject -TstFile $TstFile -GenerateRecords:$GenerateRecords
    if ($TessaScheme.Tables.Contains($tessaTable.id)){
        if ($Null -eq $TessaScheme.Tables[$tessaTable.id].name){
            $TessaScheme.Tables[$tessaTable.id].name=$tessaTable.name
        }
        if ($Null -eq $TessaScheme.Tables[$tessaTable.id].partitionId){
            $TessaScheme.Tables[$tessaTable.id].partitionId=$tessaTable.partitionId
        }
        if ($Null -eq $TessaScheme.Tables[$tessaTable.id].group){
            $TessaScheme.Tables[$tessaTable.id].group=$tessaTable.group
        }
        if ($Null -eq $TessaScheme.Tables[$tessaTable.id].description){
            $TessaScheme.Tables[$tessaTable.id].description=$tessaTable.description
        }
        $TessaScheme.Tables[$tessaTable.id].columns+=$tessaTable.columns
        $TessaScheme.Tables[$tessaTable.id].records+=$tessaTable.records
    } else {
        $TessaScheme.Tables[$tessaTable.id]=$tessaTable
    }
}



function Add-TessaSchemeOrPartitionToObject
{
    [CmdletBinding()]
    param(
        $TessaScheme,
        [string] $SchemeFile,
        [ValidateSet('Scheme','Partition')][string] $Type,
        [switch] $GenerateEnums,
        [switch] $GenerateClasses,
        [switch] $GenerateLinks,
        [switch] $GenerateRecords
    )

    if (!(Test-Path -Path $SchemeFile)){
        Write-Error "Incorrect path to .tsd file: $SchemeFile"
    }
    Write-Host "Processing $SchemeFile ($type)"
    $schemePath=Split-Path -Parent $SchemeFile
    [xml] $tsdXml = Get-Content -Path $SchemeFile

    if ($Type -eq 'Scheme')
    {
        #Заполняем словарь имен библиотек (partitions)
        foreach ($partition in $tsdXml.SchemeDatabase.SchemePartition){
            $TessaScheme.Dictionaries.PartitionNames[$partition.ID]=$partition.Name
        }
        
        foreach ($table in $tsdXml.SchemeDatabase.SchemeTable)
        {
            $TessaScheme.Dictionaries.TableNames[$table.ID]=$table.Name
            
            $tstFile=Join-Path -Path $schemePath -Child "Tables\$($table.Name).tst"
            Add-TessaTableToObject -TessaScheme $TessaScheme -TstFile $tstFile `
                                -SubPackage $tsdXml.SchemeDatabase.Name `
                                -GenerateEnums:$GenerateEnums -GenerateClasses:$GenerateClasses `
                                -GenerateLinks:$GenerateLinks -GenerateRecords:$GenerateRecords -Verbose
        }
    } else {
        #Заполняем словарь имен библиотек (partitions)
        $TessaScheme.Dictionaries.PartitionNames[$tsdXml.SchemePartition.ID]=$tsdXml.SchemePartition.Name
        
        foreach ($table in $tsdXml.SchemePartition.SchemeTable)
        {
            $TessaScheme.Dictionaries.TableNames[$table.ID]=$table.Name
            
            $tstFile=Join-Path -Path $schemePath -Child "Tables\$($table.Name).tst"
            Add-TessaTableToObject -TessaScheme $TessaScheme -TstFile $tstFile `
                                -SubPackage $tsdXml.SchemePartition.Name `
                                -GenerateEnums:$GenerateEnums -GenerateClasses:$GenerateClasses `
                                -GenerateLinks:$GenerateLinks -GenerateRecords:$GenerateRecords -Verbose
        }
    }
}

function Get-TessaSchemeObject
{
    [CmdletBinding()]
    param(
        [string] $SchemeFolder,
        [switch] $GenerateEnums,
        [switch] $GenerateClasses,
        [switch] $GenerateLinks,
        [switch] $GenerateRecords,
        [switch] $DeleteUnnecessary
    )

    $tessaScheme=@{}
    $tessaScheme.Tables=@{}
    $tessaScheme.Dictionaries=@{}
    $tessaScheme.Dictionaries.PartitionNames=@{}
    $tessaScheme.Dictionaries.TableNames=@{}
    Write-Verbose "Searching .tsd files in $SchemeFolder"
    $tsdFiles = Get-ChildItem -Path $SchemeFolder -Include *.tsd -Recurse
    foreach($tsdFile in $tsdFiles){
        Add-TessaSchemeOrPartitionToObject -TessaScheme $tessaScheme -SchemeFile $tsdFile -Type 'Scheme' `
                            -GenerateEnums:$GenerateEnums -GenerateClasses:$GenerateClasses `
                            -GenerateLinks:$GenerateLinks -GenerateRecords:$GenerateRecords
    }

    Write-Verbose "Searching .tsp files in $SchemeFolder"
    $tspFiles = Get-ChildItem -Path $SchemeFolder -Include *.tsp -Recurse
    foreach($tspFile in $tspFiles){
        Add-TessaSchemeOrPartitionToObject -TessaScheme $tessaScheme -SchemeFile $tspFile -Type 'Partition' `
                            -GenerateEnums:$GenerateEnums -GenerateClasses:$GenerateClasses `
                            -GenerateLinks:$GenerateLinks -GenerateRecords:$GenerateRecords
    }

    #Заполняем поля именами по справочником. Можно делать только после перебора всех файлов, т.к. есть кросс-ссылки
    foreach($table in $tessaScheme.Tables.Values){
        if ($Null -ne $table.partitionId){
            $table.partitionName=$tessaScheme.Dictionaries.PartitionNames[$table.partitionId]    
        } else {
            $table.partitionName=$DefaultPartitionName
        }
        $table.namespace=$table.partitionName -replace '\s',''
    }
    
    foreach($table in $tessaScheme.Tables.Values){
        foreach($column in $table.columns){
            if ($Null -ne $column.tableId){
                $column.tableName=$tessaScheme.Dictionaries.TableNames[$column.tableId]
                $column.tablePartitionId=$tessaScheme.Tables[$column.tableId].partitionId
                $column.tablePartitionName=$tessaScheme.Tables[$column.tableId].partitionName
                $column.tableNamespace=$tessaScheme.Tables[$column.tableId].namespace
                $column.tableFullName=$column.tableNamespace+"."+$column.tableName
                $column.tableGroup=$column.tableNamespace+"."+$column.tableName
            }
            if ($Null -ne $column.partitionId){
                $column.partitionName=$tessaScheme.Dictionaries.PartitionNames[$column.partitionId]
            } else {
                $column.partitionId=$table.partitionId
                $column.partitionName=$table.partitionName
            }
        }
    }
    
    return $tessaScheme
}

Export-ModuleMember -Function Get-TessaSchemeObject