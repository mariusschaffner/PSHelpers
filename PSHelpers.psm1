# Ensure module path is correct
$ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import Public functions
$PublicFunctions = Get-ChildItem -Path "$ModuleRoot/Public" -Filter "*.ps1" -Recurse
foreach ($Function in $PublicFunctions) {
    Try {
        . $Function.FullName
    } Catch {
        Write-Error "Failed to load $($Function.Name): $_"
    }
}

# Import Private functions (if needed internally)
$PrivateFunctions = Get-ChildItem -Path "$ModuleRoot/Private" -Filter "*.ps1" -Recurse
foreach ($Function in $PrivateFunctions) {
    Try {
        . $Function.FullName
    } Catch {
        Write-Error "Failed to load private function $($Function.Name): $_"
    }
}

Export-ModuleMember -Function @($PublicFunctions.BaseName)