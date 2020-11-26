function Format-Json {
    <#
    .SYNOPSIS
        Prettifies JSON output.
    .DESCRIPTION
        Reformats a JSON string so the output looks better than what ConvertTo-Json outputs. https://stackoverflow.com/questions/56322993/proper-formating-of-json-using-powershell            
    .PARAMETER Json
        Required: [string] The JSON text to prettify.
    .PARAMETER Minify
        Optional: Returns the json string compressed.
    .PARAMETER Indentation
        Optional: The number of spaces (1..1024) to use for indentation. Defaults to 4.
    .PARAMETER AsArray
        Optional: If set, the output will be in the form of a string array, otherwise a single string is output.
    .EXAMPLE
        $json | ConvertTo-Json  | Format-Json -Indentation 2
    #>
    [CmdletBinding(DefaultParameterSetName = 'Prettify')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Json,

        [Parameter(ParameterSetName = 'Minify')]
        [switch]$Minify,

        [Parameter(ParameterSetName = 'Prettify')]
        [ValidateRange(1, 1024)]
        [int]$Indentation = 4,

        [Parameter(ParameterSetName = 'Prettify')]
        [switch]$AsArray
    )

    if ($PSCmdlet.ParameterSetName -eq 'Minify') {
        return ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100 -Compress
    }

    # If the input JSON text has been created with ConvertTo-Json -Compress
    # then we first need to reconvert it without compression
    if ($Json -notmatch '\r?\n') {
        $Json = ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100
    }

    $indent = 0
    $regexUnlessQuoted = '(?=([^"]*"[^"]*")*[^"]*$)'

    $result = $Json -split '\r?\n' |
            ForEach-Object {
                # If the line contains a ] or } character, 
                # we need to decrement the indentation level unless it is inside quotes.
                if ($_ -match "[}\]]$regexUnlessQuoted") {
                    $indent = [Math]::Max($indent - $Indentation, 0)
                }

                # Replace all colon-space combinations by ": " unless it is inside quotes.
                $line = (' ' * $indent) + ($_.TrimStart() -replace ":\s+$regexUnlessQuoted", ': ')

                # If the line contains a [ or { character, 
                # we need to increment the indentation level unless it is inside quotes.
                if ($_ -match "[\{\[]$regexUnlessQuoted") {
                    $indent += $Indentation
                }

                $line
            }

    if ($AsArray) { return $result }
    return $result -Join [Environment]::NewLine
}

function Merge-Jsons () {
    [CmdletBinding()]
    param(
        $Target,
        $Source
    )
    
    $Source.psobject.Properties | % {
        if ($_.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject' -and $Target."$($_.Name)" ) {
            Merge-Jsons $Target."$($_.Name)" $_.Value
        }
        else {
            $Target | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value -Force
        }
    }
}

function Merge-JsonFiles(){
    <#
    .SYNOPSIS
        Merge several JSON files to one.
    .DESCRIPTION
        Merges several FilesToMerge into a single TargetFile. 
    .PARAMETER TargetFile
        Required: [string] Target file path for merged JSON.
    .PARAMETER FilesToMerge
        Required: Files which should be merged. The next file overrides data parts of previous if they are the same
    #>
    [CmdletBinding()]
    param(
        [string] $TargetFile,
        [string[]] $FilesToMerge
    )
    $targetJson=@{}
    foreach($fileToMerge in $FilesToMerge){
        $jsonToMerge=Get-Content -Path $fileToMerge -Raw | ConvertFrom-Json
        Merge-Jsons -Target $targetJson -Source $jsonToMerge
    }
    $targetStr=$targetJson | ConvertTo-Json -Depth 5 | Format-Json
    Set-Content -Path $TargetFile -Value $targetStr -Force;
}

Export-ModuleMember -Function Merge-JsonFiles