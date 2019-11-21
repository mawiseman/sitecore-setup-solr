
# Import Modules

Import-Module $PSScriptRoot\modules\menu.psm1
Import-Module $PSScriptRoot\modules\write-ascii\write-ascii.psd1
Import-Module $PSScriptRoot\modules\sitecore-solr\sitecore-solr.psm1
Import-Module $PSScriptRoot\modules\solr.psm1

# Render Menu

$SitecoreSolrOptions = Get-SitecoreSolrOptions
$SitecoreSolrOptions.Add("custom", "Custom Version")
$SitecoreSolrOptions.Add("cancel", "cancel")

$SelectedOption = ShowMenu "Select Solr version" $SitecoreSolrOptions

if($SelectedOption -eq "cancel") {
	Write-Ascii "Bye Bye" -ForegroundColor Red
	return
}

if($SelectedOption -eq "custom") {
	InstallSolr
}
else {
	$SolrOption = Get-SitecoreSolrOption -version $SelectedOption

	InstallSolr -solrVersion $SolrOption.Version -solrPort $SolrOption.Port
}

Write-Ascii "Solr $SelectedOption" -ForegroundColor Green