<#
.SYNOPSIS
Prints a pretty git status output

.DESCRIPTION
Uses custom scripting to pring a detailed and pretty styled git status output improving design and readybility

.EXAMPLE
PS> Show-GitStatus

.EXAMPLE
PS> gs
#>
function Show-GitStatus {
    [CmdletBinding()]
    param()

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host " Git is not installed or not in PATH." -ForegroundColor Red
        return
    }

    $status = git status --porcelain=v2 --branch
    if (-not $status) {
        Write-Host " Clean working tree!" -ForegroundColor Green
        return
    }

    # --- Branch Info ---
    $branch   = ($status | Where-Object { $_ -like '# branch.head*' }) -replace '# branch.head ', ''
    $upstream = ($status | Where-Object { $_ -like '# branch.upstream*' }) -replace '# branch.upstream ', ''
    $ahead    = ($status | Where-Object { $_ -like '# branch.ab*' }) -replace '# branch.ab ', ''

    $aheadCount = 0
    $behindCount = 0
    if ($ahead) {
        $split = $ahead.Split(' ')
        $aheadCount = [int]($split[0].Replace('+',''))
        $behindCount = [int]($split[1].Replace('-',''))
    }

    # --- Tag Info ---
    $tagAtHead   = git describe --tags --exact-match 2>$null
    $nearestTag  = git describe --tags 2>$null
    $remoteTags  = (git ls-remote --tags $upstream 2>$null) -replace '.*refs/tags/', ''
    $localTags   = git tag --points-at HEAD
    $unpushedTags = $localTags | Where-Object { $_ -and ($_ -notin $remoteTags) }

    Write-Host ""
    if ($tagAtHead) {
        Write-Host "  On tag:" -NoNewline -ForegroundColor DarkYellow
        Write-Host " $tagAtHead" -ForegroundColor Cyan
    } elseif ($nearestTag) {
        Write-Host "  Nearest tag:" -NoNewline -ForegroundColor DarkYellow
        Write-Host " $nearestTag" -ForegroundColor DarkCyan
    }
    if ($unpushedTags) {
        foreach ($t in $unpushedTags) {
            Write-Host "  Unpushed tag:" -NoNewline -ForegroundColor DarkYellow
            Write-Host " $t" -ForegroundColor Magenta
        }
    }

    # --- Remote commits not pulled ---
    if ($behindCount -gt 0 -and $upstream) {
        Write-Host ""
        Write-Host "  Remote: " -NoNewline -ForegroundColor Magenta
        Write-Host "[ $behindCount]" -NoNewline -ForegroundColor DarkMagenta
        Write-Host " | $upstream" -NoNewline -ForegroundColor Green
        Write-Host " | (git pull)" -ForegroundColor DarkGray
        Write-Host " ───────────────────────────────" -ForegroundColor DarkGray
        $commits = git log "HEAD..$upstream" --pretty=format:"%h %s" -n $behindCount
        foreach ($c in $commits) {
            Write-Host "   󰇚 $c" -ForegroundColor DarkRed
        }
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  Remote: " -NoNewline -ForegroundColor Magenta
        Write-Host "[ $behindCount]" -NoNewline -ForegroundColor DarkGray
        Write-Host " | $upstream" -ForegroundColor Green
    }

    # --- Local commits not pushed ---
    if ($aheadCount -gt 0) {
        Write-Host "  HEAD:   " -NoNewline -ForegroundColor Magenta
        Write-Host "[ $aheadCount]" -NoNewline -ForegroundColor DarkCyan
        Write-Host " | $branch" -NoNewline -ForegroundColor Yellow
        Write-Host " | (git push)" -ForegroundColor DarkGray
        Write-Host " ───────────────────────────────" -ForegroundColor DarkGray
        #if ($upstream) {
        #    $commits = git log "$upstream..HEAD" --pretty=format:"%h %s" -n $aheadCount
        #} else {
        #    $commits = git log HEAD --pretty=format:"%h %s" -n $aheadCount
        #}
        #foreach ($c in $commits) {
        #    Write-Host "    $c" -ForegroundColor DarkGreen
        #}

        # find upstream
        $status = git status --porcelain=v2 --branch
        $upstream = ($status | Where-Object { $_ -like '# branch.upstream*' }) -replace '# branch.upstream ', ''
        if (-not $upstream) {
            $upstream = "origin/HEAD"
        }

        # get commits with graph
        $log = git log --oneline --decorate --graph -n 7

        # figure out unpushed commits
        $unpushed = @()
        if ($upstream) {
            $unpushed = git log "$upstream..HEAD" --pretty=format:"%h"
        }

        foreach ($line in $log) {
            if ($line -match '([0-9a-f]{7,})') {
                $sha = $matches[1]
                if ($unpushed -contains $sha) {
                    # highlight unpushed commits
                    Write-Host "   $($line)" -ForegroundColor Green
                } else {
                    # dim already pushed commits
                    Write-Host "   $($line)" -ForegroundColor DarkGray
                }
            } else {
                # just in case line doesn’t match
                Write-Host "   $($line)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "  HEAD:   " -NoNewline -ForegroundColor Magenta
        Write-Host "[ $aheadCount]" -NoNewline -ForegroundColor DarkGray
        Write-Host " | $branch" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host " ───────────────────────────────"
    Write-Host ""

    # --- File Buckets ---
    $staged   = @()
    $unstaged = @()
    $untracked = @()

    foreach ($line in $status) {
        if ($line -match '^\? (.+)$') {
            $untracked += $matches[1]
        }
        elseif ($line -match '^[12] (\S)(\S) .* (.+)$') {
            $X = $matches[1]
            $Y = $matches[2]
            $file = $matches[3]

            if ($X -ne '.') { $staged += "$X $file" }
            if ($Y -ne '.') { $unstaged += "$Y $file" }
        }
    }

    if ((-not $staged) -and (-not $unstaged) -and (-not $untracked) -and ($aheadCount -eq 0)) {
        git log --oneline --decorate --graph -n 7
    }

    if ($staged) {
        Write-Host "  Staged changes ($($staged.Count))" -NoNewline -ForegroundColor Green
        Write-Host " | (gcc | git restore --staged)" -ForegroundColor DarkGray
        foreach ($entry in $staged) {
            $parts = $entry.Split(" ",2)
            $code,$file = $parts
            switch ($code) {
                'M' { Write-Host "      $file" -ForegroundColor DarkGreen }
                'A' { Write-Host "      $file" -ForegroundColor DarkGreen }
                'D' { Write-Host "      $file" -ForegroundColor DarkGreen }
                'R' { Write-Host "      $file" -ForegroundColor DarkGreen }
            }
        }
        Write-Host ""
    }

    if ($unstaged) {
        Write-Host "  Unstaged changes ($($unstaged.Count))" -NoNewline -ForegroundColor Yellow
        Write-Host " | (ga | git restore)" -ForegroundColor DarkGray
        foreach ($entry in $unstaged) {
            $parts = $entry.Split(" ",2)
            $code,$file = $parts
            switch ($code) {
                'M' { Write-Host "      $file" -ForegroundColor DarkYellow }
                'D' { Write-Host "      $file" -ForegroundColor DarkYellow }
            }
        }
        Write-Host ""
    }

    if ($untracked) {
        Write-Host "  Untracked ($($untracked.Count))" -NoNewline -ForegroundColor Magenta
        Write-Host " | (ga)" -ForegroundColor DarkGray
        $untracked | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkMagenta }
        Write-Host ""
    }
}
