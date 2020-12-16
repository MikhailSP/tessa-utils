
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

function New-TessaPhysicalColumnPartInfo{
    [CmdletBinding()]
    param(
        $Table,
        $Column
    )
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
    $info+="        $($Column.name),`r`n`r`n"
    $info
}

function New-TessaComplexColumnPartInfo{
    [CmdletBinding()]
    param(
        $TessaScheme,
        $Table,
        $Column
    )
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
    $info+="        $($Column.name),`r`n`r`n"
    $info
}

function New-TessaTableEnumHeader{
    [CmdletBinding()]
    param(
        $Table,
        [string] $SubPackage
    )
    $content="namespace Tessa.Extensions.Shared.$SubPackage`r`n"
    $content+="{`r`n"
    $content+="    /// <summary>`r`n"
    $content+=Get-MultilineRow -Prefix "    /// " -Values $Table.description
    $content += "    /// Группа: $($Table.group)`r`n"
    $content += "    /// Библиотека: $($Table.partitionName) ($($Table.partitionId))`r`n"
    $content += "    /// Используется для типа: $($Table.instanceType)`r`n"
    $content += "    /// Тип секции: $($Table.contentType)`r`n"
    $content += "    /// ID: $($Table.id)`r`n"
    $content+="    /// </summary>`r`n"
    $content+="    public enum $($Table.name)`r`n"
    $content+="    {`r`n"
    $content
}

function New-TessaTableEnumContent{
    [CmdletBinding()]
    param(
        $TessaScheme,
        $Table,
        [string] $SubPackage
    )

    $content = New-TessaTableEnumHeader -Table $Table -SubPackage $SubPackage
    foreach ($column in $Table.columns){
        if ($column.category -eq 'Physical'){
            $content+=New-TessaPhysicalColumnPartInfo -Table $Table -Column $column
        }
        elseif ($column.category -eq 'Complex')
        {
            $content+=New-TessaComplexColumnPartInfo -TessaScheme $TessaScheme -Table $Table -Column $column
        }
    }
    $content+="    }`r`n"
    $content+="}"
    return $content
}

Export-ModuleMember -Function New-TessaTableEnumContent