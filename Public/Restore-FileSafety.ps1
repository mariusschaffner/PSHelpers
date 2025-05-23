<#
.SYNOPSIS
    Restores files or directories from the trash folder created by Remove-FileSafety.ps1

.DESCRIPTION
    Restores trashed items (files or folders) by name from the trash directory to the current working directory.
    Timestamp suffix is removed from the restored item's name.

.PARAMETER Name
    One or more names (or partial names) of files/folders to restore.

.PARAMETER TrashDirectory
    The directory where trashed files/folders are stored. Defaults to "\tmp\tmp_trash".

.EXAMPLE
    Restore-FileSafety myfile.txt

.EXAMPLE
    Restore-FileSafety file1.txt folder1 -TrashDirectory "D:\mytrash"

.EXAMPLE
    # Example with Alias
    restore file1.txt folder1 -TrashDirectory "D:\mytrash"
#>
function Restore-FileSafety {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Enter one or more file or directory to be restored safely"
        )]
        [string[]]$TargetPaths,

        [string]$TrashDirectory = "\tmp\tmp_trash"
    )

    # Check if the trash directory exists
    if (-not (Test-Path $TrashDirectory)) {
        Write-Warning "Trash directory '$TrashDirectory' does not exist. Nothing to restore."
        return
    }

    # Get list of trashed items
    $trashedItems = Get-ChildItem -Path $TrashDirectory

    if (!$trashedItems) {
        Write-Host "Trash is empty."
        return
    }

    foreach ($pattern in $TargetPaths) {
        # Find trashed items that match the passed name or pattern (case-insensitive, partial match)
        $matchingItems = $trashedItems | Where-Object { $_.Name -like "*$pattern*" }
        if (!$matchingItems) {
            Write-Warning "No trashed item found matching '$pattern'."
            continue
        }

        foreach ($trashedItem in $matchingItems) {
            # Remove timestamp (last dot + 15 chars, e.g. ".20240523_064523")
            $baseName = $trashedItem.Name -replace '\.\d{8}_\d{6}$', ''
            $restorePath = Join-Path $PWD $baseName

            try {
                Move-Item -Path $trashedItem.FullName -Destination $restorePath -Force
                Write-Host "'$baseName' restored to '$restorePath'." -ForegroundColor Green
            } catch {
                Write-Error "Failed to restore '$($trashedItem.Name)': $_" -ForegroundColor Red
            }
        }
    }
}
