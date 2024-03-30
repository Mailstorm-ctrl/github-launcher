<#
.SYNOPSIS
Clone a github repo via SSH to a temporary directory or running users profile, then execute it.

.PARAMETER sshkey
Specify the FULL PATH of the sshkey used to connect to the repo. The sshkey specified must be able to read the repository.

.PARAMETER url
Specify the URL of the remote repo to clone. Takes the web url or the HTTPS clone link and converts it to use SSH.

.PARAMETER startfile
Specify the name of the file this launcher should run once cloned. Default is runme. Do NOT include the extension of the file!

.PARAMETER cache
Toggle the ability to download the repo once and store it in the running users profile. This will download the repo once and never update it unless the local folder is removed.

.PARAMETER arguments
Arbitrary string of arguments to pass to the runme file.
 
.EXAMPLE
Clone reponame on every run and specify the filename "start" as the way to invoke the script(s)
.\launcher.ps1 -sshkey ~/.ssh/repokey -url https://github.com/organization-name/reponame -startfile "start"

.EXAMPLE
Clone reponame to users profile only once and pass an argument of "apisecret 123456789abcdefgh" to a file named runme
.\launcher.ps1 -sshkey ~/.ssh/repokey -url https://github.com/organization-name/reponame/folder1/folder2 -cache:$true -arguments "-apisecret 123456789abcdefgh"
#>
param(
    [Parameter(Mandatory=$true,
    HelpMessage="Specify the FULL path to sshkey file used to access specified repo.")]
    [string]$sshkey,
    [Parameter(Mandatory=$true,
    HelpMessage="Github web address of the repo to clone. Do NOT use ssh URL.")]
    [ValidatePattern("https://github.com/(.*)")]
    [string]$url,
    [string]$startfile="runme",
    [bool]$cache=$false,
    [string]$arguments
)

function install-winget{
    $API_URL = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $DOWNLOAD_URL = $(Invoke-RestMethod $API_URL).assets.browser_download_url |
    Where-Object {$_.EndsWith(".msixbundle")}
    Invoke-WebRequest -URI $DOWNLOAD_URL -OutFile winget.msixbundle -UseBasicParsing
    Add-AppxPackage winget.msixbundle
    Remove-Item winget.msixbundle
}
function install-git{
    Start-Process winget.exe -Argumentlist "install --id Git.Git -e --source winget"
}

function git{
    & (Get-Command git -commandType Application) @args 2>&1
}

function test-success{
    param(
        $gitOut
    )
    if ($null -eq $gitOut[1]){
        [void]'boo'
    }
    elseif ($gitOut[1] -match "No such file or directory"){
        throw "Specified SSH Key file not found."
    }
    elseif ($gitOut[1] -match "Permission denied"){
        throw "SSH Key does not have read access to $sshurl"
    }
    else {
        Write-Error $gitOut
        throw "Something happened. Repo was not cloned."
    }
}
#TODO: Get latest release instead of just pulling from master. Must work with SSH

# Allows users to paste in ANY URL of the repo. Example:
# https://github.com/org/repo/source/bin
# https://github.com/org/repo.git
# Both will return git@github.com:org/repo.git
$url -match "https://github.com/(?<repo>.*)" | Out-Null
$matches['repo'] -match "(?<clean>^([^\/]*\/){1}[^\/]*)" | Out-Null
$sshurl = "git@github.com:$($matches['clean'])"
if (-not ($sshurl.Substring($sshurl.length-4) -eq ".git")){
    $sshurl = "git@github.com:$($matches['clean']).git"
}
# Test for git
try {
    Get-Command git | Out-Null
}
catch [System.Management.Automation.CommandNotFoundException] {
    try {
        Get-Command winget
        $input = Read-Host "Git wasn't found on this system. Would you like to install git? (y/n)"
        if($input.ToLower() -in "y","1","yes"){
            install-git
        }
        else{
            throw "Git is required to use this launcher. You can install git manually if you wish then rerun the launcher. Exiting."
        }
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        $input = Read-Host "Git wasn't found on this system. Would you like to install winget and git? (y/n)"
        if($input.ToLower() -in "y","1","yes"){
            install-winget
            install-git
        }
        else {
            throw "Git is required to use this launcher. You can install git manually if you wish then rerun the launcher. Exiting."
        }
    }
}

$sshkey = $sshkey.Replace('\','\\')

#TODO: Check for version difference without DL. Must work with SSH
if($cache){
    $destination = "$($env:USERPROFILE)/github_launcher/$repo"
}
else{
    $guid = [System.Guid]::NewGuid().ToString()
    $destination = "$($env:TEMP)/github_launcher/$(Get-Date -format "dd.mm.yyyy_HH.mm")-$guid"
}

if (-not (Test-Path $destination)){
    $gitOut = git clone -c core.sshCommand="ssh -i $sshkey" $sshurl $destination
    test-success -gitOut $gitOut
}

$ignore_extensions = @(".txt",".md",".json",".png",".jpg",".zip",".rar",".7z")
$executed = $false
$runmes = Get-ChildItem "$destination\$startfile.*"
foreach ($runme in $runmes.Name){
    $lastindex = $runme.LastIndexOf(".")
    # We find the LAST . of the file we are looking for and mark it's location in string
    # We take the length of the total filename minus the index position to ensure we get the file extension name
    $extension = $runme.substring($lastindex,$runme.length-$lastindex)
    if($extension -notin $ignore_extensions -and !$executed){
        switch ($extension){
            { $_ -eq ".ps1" } {
                Start-Process powershell -ArgumentList "-File $destination\$runme $arguments" -Wait
                $executed = $true
            }
        }
    }
}
if (!$executed){
    Write-Warning "No action performed. Could not find a file named $startfile or did not understand how to launch $startfile."
}
if (!$cache){
    Remove-Item -LiteralPath $destination -Force -Recurse
}
