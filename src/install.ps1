# Import Modules

Import-Module $PSScriptRoot\modules\menu.psm1
Import-Module $PSScriptRoot\modules\write-ascii\write-ascii.psd1
Import-Module $PSScriptRoot\modules\sitecore-solr\sitecore-solr.psm1
Import-Module $PSScriptRoot\modules\solr.psm1

# Prepare Menu

$SitecoreSolrOptions = Get-SitecoreSolrOptions
$SitecoreSolrOptions.Add("custom", "Custom Version")
$SitecoreSolrOptions.Add("cancel", "Cancel")

# Get Action

$Action = ShowMenu "Select Solr Version:" $SitecoreSolrOptions
Write-Host ""

# Process Action

if($Action -eq "cancel") {
	Write-Ascii "Bye Bye" -ForegroundColor Red
}
elseif($Action -eq "custom") {
	InstallSolr
	Write-Ascii "Solr $Action" -ForegroundColor Green
}
else {
	$SolrOption = Get-SitecoreSolrOption -version $Action

	InstallSolr -solrVersion $SolrOption.Version -solrPort $SolrOption.Port
	Write-Ascii "Solr $Action" -ForegroundColor Green
}