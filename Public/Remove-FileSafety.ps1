<#
.SYNOPSIS
    Safely removes files or directories by moving themto a designated trash folder with a timestamp, after user confirmation.

.DESCRIPTION
    This function prevents accidental deletion by:
      - Prompting the user for confirmation before removing.
      - Moving the specified file or directory (including all its contents) to a trash folder.
      - Appending a timestamp to the moved item to avoid name collisions and track deletion time.
      - Creating the trash folder if it does not exist.

.PARAMETER TargetPaths
    One or more file or directory paths to be safely "removed".

.PARAMETER TrashDirectory
    The directory where deleted items are stored. Defaults to "\tmp\tmp_trash".

.EXAMPLE
    Remove-FileSafety .\myfile.txt

.EXAMPLE
    Remove-FileSafety .\file1.txt .\folder1 -TrashDirectory "D:\mytrash"

.EXAMPLE
    #

    # with function alias
    delete .\file1.txt .\folder1
    delete .\file1.txt .\folder1 -TrashDirectory "D:\mytrash"

.NOTES
    - Works for both files and directories (including nested contents).
    - Does not permanently delete; recovery is possible from the trash directory.
#>
function Remove-FileSafety {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Enter one or more file or directory to be removed safely"
        )]
        [string[]] $TargetPaths,

        [string] $TrashDirectory = "\tmp\tmp_trash"
    )

    begin {
        # Ensure the trash directory exists; create it if not.
        if (-not (Test-Path $TrashDirectory)) {
            New-Item -Path $TrashDirectory -ItemType Directory | Out-Null
        }
    }

    process {
        foreach ($originalPath in $TargetPaths) {
            # Check if the target path exists before proceeding.
            if (-not (Test-Path $originalPath)) {
                Write-Warning "'$originalPath' does not exist."
                continue
            }

            # Prompt the user for confirmation before moving the item.
            $confirmation = Read-Host "Are you sure you want to move '$originalPath' to the trash folder? [Y/N]"
            if ($confirmation -notmatch '^(Y|y)') {
                Write-Host "Skipping '$originalPath'."
                continue
            }

            # Prepare the destination path with a timestamp to prevent overwriting.
            $itemName = Split-Path $originalPath -Leaf
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $trashedName = "${itemName}.${timestamp}"
            $destinationPath = Join-Path $TrashDirectory $trashedName

            try {
                # Move the file or directory (with all contents) to the trash folder.
                Move-Item -Path $originalPath -Destination $destinationPath -Force
                Write-Host "'$originalPath' has been moved to '$destinationPath'." -ForegroundColor Green
            } catch {
                Write-Error "Failed to move '$originalPath': $_" -ForegroundColor Red
            }
        }
    }
}