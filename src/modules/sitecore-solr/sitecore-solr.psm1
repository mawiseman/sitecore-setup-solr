function Get-SolrVersionsXML {
    begin {
        $SolrVersions = [ordered]@{}
    }
    process {
        $SolrVersionFile = Join-Path $PSScriptRoot 'sitecore-solr-versions.xml'
        $Xml = [xml] (Get-Content $SolrVersionFile)
    
        $Xml.solrVersions.solrVersion | ForEach-Object {
            $SolrVersions.($_.version) = New-Object PSObject -Property @{
                'Version'  = $_.version
                'Sitecore' = $_.sitecore
                'Port'     = $_.port
            }
        }
    
        $SolrVersions
    }
}

function Get-SitecoreSolrOptions {
    begin {
        $SolrOptions = [ordered]@{}
    }
    process {
        $SolrVersions = Get-SolrVersionsXML

        $SolrVersions.keys | ForEach-Object {
            $DisplayName = "Solr $($_) ($($SolrVersions[$_].Sitecore), Port: $($SolrVersions[$_].Port))" 
            $SolrOptions.Add($_, $DisplayName) 
        }

        $SolrOptions
    }
}

function Get-SitecoreSolrOption {
    param ( 
        [Parameter(Mandatory = $True)][string]$version
    )
    process {
        $SolrVersions = Get-SolrVersionsXML

        $SolrVersions[$version]
    }
}

Export-ModuleMember Get-SitecoreSolrOption, Get-SitecoreSolrOptions