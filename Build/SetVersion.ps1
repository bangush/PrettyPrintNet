<#
.SYNOPSIS
    Update the project version.
.DESCRIPTION
    Updates the nuget .nuspec file and all AssemblyInfo.cs files.
.PARAMETER SetVersion
    Set new version
.PARAMETER BumpVersion
    Bump major, minor, patch or semver label number. Only one can be specified at a time, and bumping one part will reset all the lesser parts.	
.EXAMPLE
	Set new version.
	-v 2.3.4-beta3: 1.0.0 => 2.3.4-beta3	
.EXAMPLE
	Bump the major, minor, patch or label part of the version.
	-b major: 1.2.3-alpha1 => 2.0.0
	-b minor: 1.2.3-alpha1 => 1.3.0
	-b patch: 1.2.3-alpha1 => 1.2.4
	-b label: 1.2.3-alpha => 1.2.3-alpha2
	-b label: 1.2.3-alpha2 => 1.2.3-alpha3
	-b label: 1.2.3-beta2 => 1.2.3-beta3
	-b label: 1.2.3-rc2 => 1.2.3-rc3
	
.NOTES
    Author: Andreas Gullberg Larsen
    Date:   Feb 8, 2014
	Based on original work by Luis Rocha from: http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html
#>
[CmdletBinding()]
Param(  
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="SetVersion", HelpMessage="Set version string")] 
	[Alias("v")] 
	[string]$setVersion,
	[Parameter(Mandatory=$true, Position=0, ParameterSetName="BumpVersion", HelpMessage="Bump one or more version parts")] 
	
	[Alias("b")] 
	[ValidateSet('major','minor','patch','label')]
	[string]$bumpVersion
)

#-------------------------------------------------------------------------------
# Displays how to use this script.
#-------------------------------------------------------------------------------
function Help {
	"Sets the AssemblyVersion and AssemblyFileVersion of AssemblyInfo.cs files`n"
	".\SetVersion.ps1 [VersionNumber]`n"
	"   [VersionNumber]     The version number to set, for example: 1.1.9301.0"
	"                       If not provided, a version number will be generated.`n"
}

#-------------------------------------------------------------------------------
# Description: Sets the AssemblyVersion and AssemblyFileVersion of 
#              AssemblyInfo.cs files.
#              Sets the <version></version> element of PrettyPrintNet.nuspec file.
#
# Based on original work by Luis Rocha from: http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html
#
# Author: Andreas Larsen
# Version: 1.1
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Update version numbers of AssemblyInfo.cs
#-------------------------------------------------------------------------------
function Update-AssemblyInfoFiles ([string] $version) {
    $assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $assemblyVersion = 'AssemblyVersion("' + $version + '")';
    $fileVersion = 'AssemblyFileVersion("' + $version + '")';
    
    Get-ChildItem ..\ -r | Where { $_.PSChildName -match "^AssemblyInfo\.cs$"} | ForEach-Object {
        $filename = $_.Directory.ToString() + '\' + $_.Name
        $filename + ' -> ' + $version
        
        # If you are using a source control that requires to check-out files before 
        # modifying them, make sure to check-out the file here.
        # For example, TFS will require the following command:
        # tf checkout $filename
    
        (Get-Content $filename -Encoding UTF8) | ForEach-Object {
            % {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
            % {$_ -replace $fileVersionPattern, $fileVersion }
        } | Set-Content $filename -Encoding UTF8
    }    
}

#-------------------------------------------------------------------------------
# Update <releaseNotes> element in PrettyPrintNet.nuspec
#-------------------------------------------------------------------------------
function Update-NuspecFileReleaseNotes ([string] $NuSpecFilePath, [xml] $nuspecXml, [string] $releaseInfo, [Version] $newVersion) {
	"PrettyPrintNet.nuspec -> Prepend release notes: $releaseInfo"
	$updatedReleaseNotes = [string]::Format("v{0}.{1}.{2}: {3}`n`n{4}", 
		$newVersion.Major, 
		$newVersion.Minor, 
		$newVersion.Build, 
		$releaseInfo, 
		$nuspecXml.package.metadata.releaseNotes)
		
	$nuspecXml.package.metadata.releaseNotes = $updatedReleaseNotes
	$nuspecXml.Save($NuSpecFilePath)    
}

function Update-NuspecVersion([string] $NuSpecFilePath, [xml] $nuspecXml, [string] $newSemVer) {
	"$NuSpecFilePath -> $newSemVer"
	$nuspecXml.package.metadata.version = $newSemVer
	$nuspecXml.Save($NuSpecFilePath)
}

function BumpMajor ([Version] $currentVersion) {
	return New-Object System.Version -ArgumentList ($currentVersion.Major+1), 0, 0
}

function BumpMinor([Version] $currentVersion) {
	return New-Object System.Version -ArgumentList $currentVersion.Major, ($currentVersion.Minor+1), 0
}

function BumpPatch([Version] $currentVersion) {    
	return New-Object System.Version -ArgumentList $currentVersion.Major, $currentVersion.Minor, ($currentVersion.Build+1);
}

function BumpLabel([string] $label) {
	$label = $label.Trim()
	#if ($label -eq "alpha") {	return "alpha2"; }
	#if ($label -eq "beta") { return "beta2"; }	
	
	# alpha, beta and rc labels supported
	# Example:
	# alpha => alpha2
	# alpha1 => alpha2	
	$match = [regex]::Match($label, '^-(alpha|beta|rc)(\d+)?$');
	$label = $match.Groups[1].Value
	$numberGroup = $match.Groups[2]
	
	$number = if ($numberGroup.Success) { 1+$match.Groups[2].Value } else { 2 }
	return [string]::Format("-{0}{1}", $label, $number)
}

try {
#-------------------------------------------------------------------------------
# Parse arguments.
#-------------------------------------------------------------------------------
$NuSpecFilePath = "PrettyPrintNet.nuspec"
[ xml ]$nuspecXml = Get-Content -Path $NuSpecFilePath

# Split "1.2.3-alpha" into ["1.2.3", "alpha"]
# Split "1.2.3" into ["1.2.3"]
$currentSemVer = $nuspecXml.package.metadata.version
$semVerVersionParts = $currentSemVer.Split('-')
$currentVersion = [Version]::Parse($semVerVersionParts[0])
$currentLabel = if ($semVerVersionParts.Length -eq 2) { "-" + $semVerVersionParts[1]} else { "" }

$newVersion = $currentVersion
$newLabel = $currentLabel
		
switch ($PsCmdlet.ParameterSetName) {
    "BumpVersion" {	
		switch ($bumpVersion) {
			"major" {
				$newVersion = BumpMajor $newVersion 
				$newLabel = ""
			}
			"minor" { 
				$newVersion = BumpMinor $newVersion 
				$newLabel = ""
			}	
			"patch" { 
				$newVersion = BumpPatch $newVersion 
				$newLabel = ""
			}
			"label" { 
				$newLabel = BumpLabel $newLabel
			}
		}		
		$newSemVer = $newVersion.ToString() + $newLabel
    }
	"SetVersion" {		
		$newSemVer = $setVersion
		$newSemVerVersionParts = $newSemVer.Split('-')
		
		$newVersion = [Version]::Parse($newSemVerVersionParts[0])
		$newLabel = if ($newSemVerVersionParts.Length -eq 2) { "-" + $newSemVerVersionParts[1]} else { "" }
		
	}
}

"Bump version $currentSemVer => $newSemVer"
$releaseNotes = Read-Host 'Enter release notes for .nuspec file (optional)'

Update-NuspecVersion $NuSpecFilePath $nuspecXml $newSemVer
if ($releaseNotes -ne "") {
	Update-NuspecFileReleaseNotes $NuSpecFilePath $nuspecXml $releaseNotes $newVersion
}
Update-AssemblyInfoFiles $newVersion
}
catch {
	$myError = $error[0]
    Write-Error "ERROR: Failed to update build parameters from .nuspec file: `n$myError' ]"
    exit 1
}