$ComplexLinkSuffix="Link"
$IdFieldCanBeReplacedBy="Ordinal"
$NameFieldCanBeReplacedBy="CurrencyName","Caption"

function Get-MultilineRow{
    param(
        [string]$Prefix,
        [string]$Values
    )
    if ($Null -eq $Values) {
        return ""
    }
    $content=""
    foreach ($value in $Values.Split([Environment]::NewLine)){
        if ("" -ne $value) {
            $content += $Prefix + $value + "`r`n"
        }
    }
    $content
}

function Get-CSharpType{
    [CmdletBinding()]
    param(
        $Column
    )

    if ($Null -eq $Column.type){
        Write-Error "Ошибочный тип поля $($Column.type)"
    }else{
        if ($Column.type.StartsWith("String")){
            if ($Column.type.EndsWith("Not Null")){
                return "string"
            } else {
                return "string?"
            }
        }        
        if ($Column.type.StartsWith("Decimal")){
            if ($Column.type.EndsWith("Not Null")){
                return "double"
            } else {
                return "double?"
            }
        }        
        if ($Column.type.StartsWith("Binary")){
            if ($Column.type.EndsWith("Not Null")){
                return "byte[]"
            } else {
                return "byte[]?"
            }
        }
        if ($Column.type.StartsWith("AnsiString")){
            if ($Column.type.EndsWith("Not Null")){
                return "string"
            } else {
                return "string?"
            }
        }
        
        switch ($Column.type)
        {
            "Guid Not Null" {
                return "Guid"
            }
            "Guid Null" {
                return "Guid?"
            }
            "Date Not Null" {
                return "DateTime"
            }
            "Date Null" {
                return "DateTime?"
            }
            "Time Not Null" {
                return "DateTime"
            }
            "Time Null" {
                return "DateTime?"
            }
            "DateTime Not Null" {
                return "DateTime"
            }
            "DateTime Null" {
                return "DateTime?"
            }
            "DateTime2 Not Null" {
                return "DateTime"
            }
            "DateTime2 Null" {
                return "DateTime?"
            }
            "Int64 Not Null" {
                return "long"
            }
            "Int64 Null" {
                return "long?"
            }
            "Int32 Not Null" {
                return "int"
            }
            "Int32 Null" {
                return "int?"
            }
            "UInt32 Not Null" {
                return "int"
            }
            "UInt32 Null" {
                return "int?"
            }
            "Int16 Not Null" {
                return "short"
            }
            "Int16 Null" {
                return "short?"
            }
            "Byte Not Null" {
                return "byte"
            }
            "Byte Null" {
                return "byte?"
            }            
            "Double Not Null" {
                return "double"
            }            
            "Double Null" {
                return "double?"
            }            
            "Boolean Not Null" {
                return "bool"
            }            
            "Boolean Null" {
                return "bool?"
            }
            "Xml Not Null" {
                return "bool"
            }            
            "Xml Null" {
                return "bool?"
            }
            "Currency Not Null" {
                return "decimal"
            }            
            "Currency Null" {
                return "decimal?"
            }
            Default {
                Write-Host $Column.type
            }
        }
    }
}

function New-TessaPhysicalColumnPartInfo{
    [CmdletBinding()]
    param(
        $Table,
        $Column
    )
    $cSharpType=Get-CSharpType -Column $Column
    $info="        /// <summary>`r`n"
    $info+=Get-MultilineRow -Prefix "        /// " -Values $Column.description
    $info+="        /// Физическая`r`n"
    $info+="        /// Тип: $($Column.type)`r`n"
    $info+="        /// ID: $($Column.id)`r`n"
    $info+="        /// Библиотека: $($Column.partitionName) ($($Column.partitionId))"
    if ($Column.partitionId -ne $Table.partitionId){
        $info+=" (отличается от библиотеки таблицы: $($Table.partitionName))"
    }
    $info+="`r`n"
    $info+="        /// System: $($Column.system) Permanent: $($Column.permanent) Sealed: $($Column.sealed)`r`n"
    $info+="        /// </summary>`r`n"
    $info+="        public $cSharpType $($Column.name) {get;set;}`r`n`r`n"
    $info
}

function Get-VariableName{
    [CmdletBinding()]
    param(
        $Record
    )
    
    if ($Record.values.Contains("Name")){
        $name="_"+$Record.values['Name'] -replace '\W',''
    } 
    else
    {
        $name="ID_$($Record.values["ID"])"
    }
    $name
}

function Get-IDType{
    [CmdletBinding()]
    param(
        $Table,
        $Record
    )
    
    if (!$Record.values.Contains("ID")){
        Write-Error "No ID field for record in table '$($Table.name)'"
        return "string"
    }
    $id=$Record.values["ID"]
    if ($id -match "\w{8}-\w{4}-\w{4}-\w{4}-\w{12}"){
        return "Guid"
    }
    return "int"
}

function Replace-IdAndNameBySimilar{
    [CmdletBinding()]
    param(
        $Record
    )
    if (!$Record.values.Contains("ID")){
        foreach($canBeAsId in $IdFieldCanBeReplacedBy){
            if ($Record.values.Contains($canBeAsId)){
                $Record.values["ID"]=$Record.values[$canBeAsId]
                break
            }
        }
    }
    if (!$Record.values.Contains("Name")){
        foreach($canBeAsName in $NameFieldCanBeReplacedBy){
            if ($Record.values.Contains($canBeAsName)){
                $Record.values["Name"]=$Record.values[$canBeAsName]
                break
            }
        }
    }
}

function New-TessaRecord{
    [CmdletBinding()]
    param(
        $Table,
        $Record
    )
    
    $info="        /// <summary>`r`n"
    foreach ($key in $Record.values.Keys){
        $info+="        /// $key : $($Record.values[$key])`r`n"
    }
    $info+="        /// </summary>`r`n"

    #После комментария, чтобы не попал дубль
    Replace-IdAndNameBySimilar -Record $Record

    $cleanName=Get-VariableName -Record $Record 
    $idType=Get-IDType -Table $Table -Record $Record
    $id=$($Record.values['ID'])

    $modifier="const"
    if ("Guid" -eq $idType){
        $idValue="new Guid(`"$id`")"
        $modifier="static readonly"
    } elseif ("string" -eq $idType){
        $idValue="`"$id`""
    } else {
        $idValue=$id
    }
    
    $info+="        public $modifier $idType $cleanName=$idValue;`r`n`r`n"
    $info
}

function New-TessaComplexColumnPartInfo{
    [CmdletBinding()]
    param(
        $TessaScheme,
        $Table,
        $Column
    )
    $cSharpType=Get-CSharpType -Column $Column
    $info="        /// <summary>`r`n"
    $info+=Get-MultilineRow -Prefix "        /// " -Values $Column.description
    $info+="        /// Комплексный на колонку $($Column.columnId) таблицы $($Column.tableFullName) ($($Column.tableId))`r`n"
    $info+="        /// Тип: $($Column.type)`r`n"
    $info+="        /// ID: $($Column.id)`r`n"
    $info+="        /// Библиотека: $($Column.partitionName) ($($Column.partitionId))"
    if ($Column.partitionId -ne $Table.partitionId){
        $info+=" (отличается от библиотеки таблицы: $($Table.partitionName))"
    }
    $info+="`r`n"    
    $info+="        /// System: $($Column.system) Permanent: $($Column.permanent) Sealed: $($Column.sealed)`r`n"
    $info+="        /// </summary>`r`n"
    $info+="        public $cSharpType $($Column.name) {get;set;}`r`n`r`n"
    $info
}

function New-TessaComplexColumnRootPartInfo{
    [CmdletBinding()]
    param(
        $TessaScheme,
        $Table,
        $Column,
        [string] $Namespace,
        $TableNames
    )
    if ($Null -ne $Column.tableFullName){
        $cSharpType = "$Namespace.$($Column.tableFullName)"+"Class"
    } else {
        $cSharpType="object"
    }
    if (!$Column.type.EndsWith("Not Null")){
        $cSharpType+="?"
    }
    $info="        /// <summary>`r`n"
    $info+=Get-MultilineRow -Prefix "        /// " -Values $Column.description
    $info+="        /// Комплексный на колонку $($Column.columnId) таблицы $($Column.tableFullName) ($($Column.tableId))`r`n"
    $info+="        /// Тип: $($Column.type)`r`n"
    $info+="        /// ID: $($Column.id)`r`n"
    $info+="        /// Библиотека: $($Column.partitionName) ($($Column.partitionId))"
    if ($Column.partitionId -ne $Table.partitionId){
        $info+=" (отличается от библиотеки таблицы: $($Table.partitionName))"
    }
    $info+="`r`n"    
    $info+="        /// System: $($Column.system) Permanent: $($Column.permanent) Sealed: $($Column.sealed)`r`n"
    $info+="        /// </summary>`r`n"
    $info+="        public $cSharpType $($Column.name)$ComplexLinkSuffix {get;set;}`r`n`r`n"
    $info
}

function New-TessaTableClassHeader{
    [CmdletBinding()]
    param(
        $Table,
        [string] $SubPackage,
        [string] $ClassSuffix
    )
    $content="#nullable enable`r`n"
    $content+="using System;`r`n"
    $content+="using Tessa.Extensions.Shared.Orm;`r`n"
    $content+="using Tessa.Platform.Data;`r`n"
    $content+="namespace Tessa.Extensions.Shared.$SubPackage`r`n"
    $content+="{`r`n"
    $content+="    /// <summary>`r`n"
    $content+=Get-MultilineRow -Prefix "    /// " -Values $Table.description
    $content += "    /// Группа: $($Table.group)`r`n"
    $content += "    /// Библиотека: $($Table.partitionName) ($($Table.partitionId))`r`n"
    $content += "    /// Используется для типа: $($Table.instanceType)`r`n"
    $content += "    /// Тип секции: $($Table.contentType)`r`n"
    $content += "    /// ID: $($Table.id)`r`n"
    $content+="    /// </summary>`r`n"
    $content+="    public class $($Table.name)$($ClassSuffix)  : AutogeneratedClass<$($Table.name)>`r`n"
    $content+="    {`r`n"
    $content+="        /// <summary>`r`n"
    $content+="        /// Билдер SELECT SQL-запроса`r`n"
    $content+="        /// </summary>`r`n"
    $content+="        /// <param name=`"scope`">Скоуп БД</param>`r`n"
    $content+="        /// <returns>Билдер SQL-запроса SELECT</returns>`r`n"
    $content+="        public static SelectBuilder<$($Table.name)$($ClassSuffix), $($Table.name)> SelectBuilder(IDbScope scope)`r`n"
    $content+="        {`r`n"
    $content+="            return new SelectBuilder<$($Table.name)$($ClassSuffix), $($Table.name)>(scope);`r`n"
    $content+="        }`r`n"
    $content+="        `r`n"    
    $content+="        /// <summary>`r`n"
    $content+="        /// Билдер UPDATE SQL-запроса`r`n"
    $content+="        /// </summary>`r`n"
    $content+="        /// <param name=`"scope`">Скоуп БД</param>`r`n"
    $content+="        /// <returns>Билдер SQL-запроса UPDATE</returns>`r`n"
    $content+="        public static UpdateBuilder<$($Table.name)$($ClassSuffix), $($Table.name)> UpdateBuilder(IDbScope scope)`r`n"
    $content+="        {`r`n"
    $content+="            return new UpdateBuilder<$($Table.name)$($ClassSuffix), $($Table.name)>(scope);`r`n"
    $content+="        }`r`n"
    $content+="        `r`n"
    
    $content
}

function New-TessaTableClassContent{
    [CmdletBinding()]
    param(
        $TessaScheme,
        $Table,
        [string] $SubPackage,
        [string] $ClassSuffix,
        [string] $Namespace,
        $TableNames,
        [switch] $GenerateLinks
    )

    $content = New-TessaTableClassHeader -Table $Table -SubPackage $SubPackage -ClassSuffix $ClassSuffix
    
    foreach ($record in $Table.records){
        $content+=New-TessaRecord -Table $Table -Record $record
    }
    
    foreach ($column in $Table.columns){
        if ($column.category -eq 'Physical'){
            $content+=New-TessaPhysicalColumnPartInfo -Table $Table -Column $column
        }
        elseif ($column.category -eq 'Complex')
        {
            $content+=New-TessaComplexColumnPartInfo -TessaScheme $TessaScheme -Table $Table -Column $column
        }
        elseif (($column.category -eq 'ComplexRoot') -and $GenerateLinks)
        {
            $content+=New-TessaComplexColumnRootPartInfo -TessaScheme $TessaScheme -Table $Table -Column $column -Namespace $Namespace -TableNames $TableNames
        }
    }
    $content+="    }`r`n"
    $content+="}"
    return $content
}

Export-ModuleMember -Function New-TessaTableClassContent
