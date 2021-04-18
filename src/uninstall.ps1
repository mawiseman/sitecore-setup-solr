# Import Modules

Import-Module $PSScriptRoot\modules\menu.psm1
Import-Module $PSScriptRoot\modules\write-ascii\write-ascii.psd1
Import-Module $PSScriptRoot\modules\solr.psm1

# Check is Solr is installed

$SolrServices = GetSolrServices

if($SolrServices.Count -eq 0) {
    Write-Host "No Solr services found."
}
else
{
    # Prepare Menu

    $SolrServiceOptions = [ordered]@{}

    $SolrServices | ForEach-Object {
        $SolrServiceOptions.Add($_, $_)
    }
    $SolrServiceOptions.Add("cancel", "Cancel")

    # Get Action

    $Action = ShowMenu "Select Solr version to Uninstall:" $SolrServiceOptions
    Write-Host ""

    # Process Action

    if($Action -eq "cancel") {
        Write-Ascii "Bye Bye" -ForegroundColor Red
    }
    else {
        UninstallSolr -solrVersionName $Action

        Write-Ascii "Uninstalled" -ForegroundColor Green
    }
}
