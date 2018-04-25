param
(
   [string]$ArtifactoryServer,
   [string]$ArtifactoryUser,
   [string]$ArtifactoryPassword,
   [string]$ArtifactoryRepository,
   [string]$ArtifactPath,
   [string]$DestinationPath,
   [string]$ArtifactVersion = "latest"
)

function Get-Artifact
{
   param
   (
      [string]$ArtifactVersion,
      [string]$ArtifactoryServer,
      [string]$ArtifactoryRepository,
      [string]$ArtifactPath,
      [string]$DestinationPath,
      [string]$CacheName = "MyArtifactoryCache",
      $ArtifactoryCredentials
   )
   
   try
   {
      $DestinationPathFolder = $DestinationPath.Substring(0,$DestinationPath.Length-$DestinationPath.Split('\')[$DestinationPath.Split('\').Count-1].Length-1)
      
      if(!(Test-path($DestinationPathFolder))){New-Item $DestinationPathFolder -ItemType Directory; Write-Host "Destination folder created {$DestinationPathFolder}"}
      if(!(Test-path("$env:appdata\$CacheName\$ArtifactPath"))){New-Item "$env:appdata\$CacheName\$ArtifactPath" -ItemType Directory; Write-Host }

      # get list of artifacts by name
      $response = Invoke-WebRequest -Uri $artifactoryServer/api/search/pattern?pattern="$ArtifactoryRepository":$ArtifactPath/* -Method Get -Credential $ArtifactoryCredentials
      
      # Get all the matching artifacts from the response
      $matchingArtifacts = $response.RawContent.Split("{")[1].Split("[")[1].Split("]")[0].Split(", ").Replace('"','').trim()      
      
      # Create a List with the matching artifacts
      $matchingArtifactsList = New-Object System.Collections.ArrayList
      $matchingArtifacts | % {if($_.Length -gt 0){ $matchingArtifactsList.Add($_)}}
      
      # Create a List with the matching artifacts URLs
      $matchingArtifactsUrlsList = New-Object System.Collections.ArrayList
      $matchingArtifactsList | % {$matchingArtifactsUrlsList.Add("$artifactoryServer/api/storage/$ArtifactoryRepository/$_")}
      
      if($ArtifactPath.Length -gt 0){$URIMatches = [regex]::matches($matchingArtifactsUrlsList,'(http[s]?)(:\/\/)([^\s,]+)') | where -Property Value -match "$ArtifactoryRepository/$ArtifactPath/"}
      else {$URIMatches = [regex]::matches($matchingArtifactsUrlsList,'(http[s]?)(:\/\/)([^\s,]+)') | where -Property Value -match "$ArtifactoryRepository/"}
      
      
      if(($ArtifactVersion -eq "latest") -or !$ArtifactVersion)
      {
         # get latest version of artifact
         $ver = [regex]::matches($URIMatches, "\d+\.\d+\.\d+\.\d+").value | %{[System.Version]$_}| sort
         $ArtifactVersion = $ver[-1].ToString()
      }

      Write-Host "Artifact version: $ArtifactVersion"
      
      # get latest artifact URI
      $latestUri = ($URIMatches | where value -match $ArtifactVersion).value
      
      # get artifact filename
      $responseforartifact = Invoke-WebRequest -Uri $latestUri.TrimEnd('"') -Method Get
      $ArtifactMatches = [regex]::matches($responseforartifact.RawContent,'(http[s]?)(:\/\/)([^\s,]+)')
      $artifactFile = $ArtifactMatches[0].Value.TrimEnd('"').split("/")[-1]
      
      # file not in cache folder
      if(!(Test-path("$env:appdata\$CacheName\$ArtifactPath\$artifactFile")))
      {
         Write-Host "File {$artifactFile} is not in the cache folder, downloading from Artifactory to {$DestinationPath}..."
         
         # download file from actifactory
         Invoke-RestMethod -Method GET -Uri $ArtifactMatches[0].Value.TrimEnd('"') -OutFile $DestinationPath
         
         # copy to cache
         Copy-Item $DestinationPath -Destination $env:appdata\$CacheName\$ArtifactPath\$artifactFile
      }
      # file is in cache folder
      else
      {
         Write-Host "File {$artifactFile} found in cache folder, Getting file from cache to {$DestinationPath}..."
         
         # copy file from cache
         Copy-Item $env:appdata\$CacheName\$ArtifactPath\$artifactFile -Destination $DestinationPath
      }
   }
   catch
   {
      Write-Host -Message "Error downloading {$ArtifactoryRepository/$ArtifactPath} from {$ArtifactoryServer}, Exception: $_" -ForegroundColor Red
   }
}

# Convert credentials
$ArtifactorySecurePassword = ConvertTo-SecureString $ArtifactoryPassword -AsPlainText -Force
$ArtifactoryCredentials = New-Object System.Management.Automation.PSCredential ($ArtifactoryUser, $ArtifactorySecurePassword)

# Download Artifact
$Artifact = Get-Artifact -ArtifactVersion $ArtifactVersion -ArtifactoryServer $ArtifactoryServer -ArtifactoryRepository $ArtifactoryRepository -ArtifactPath $ArtifactPath -DestinationPath $DestinationPath -ArtifactoryCredentials $ArtifactoryCredentials

