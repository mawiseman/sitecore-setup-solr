# Introduction
This script allows you to **install** and **un-install** Solr with a valid SSL certificate via Powershell.

# Pre-requisites

Enable Remote Script Execution
```
Set-ExecutionPolicy Bypass -Scope LocalMachine -Force
```

Missing packages will be automatically installed by chocolatey... including chocolatey. You may need to re-open a new powershell instance after install

- chocolatey: https://chocolatey.org/
- nssm - the Non-Sucking Service Manager: https://nssm.cc/
- Open JDK: https://openjdk.java.net/

# Usage

## Guided Install

The default options install solr based of your version of sitecore. 

1. From an elevated powershell prompt run
```
PS C:\projects\sitecore-solr-setup\src> .\install.ps1
```

2. Select the version of Solr you'd like to install
3. Enjoy the show

### Notes
Pre-configured options are stored in an xml file and are mapped to Sitecore's compatibility table

- Sitecore Solr versions: \modules\sitecore-solr\sitecore-solr-versions.xml
- Sitecore Solr Compatibility table: https://kb.sitecore.net/articles/227897 

## Direct Install

This allows you to integrate directly with your setup process

```
PS C:\projects\sitecore-solr-setup\src> Import-Module .\modules\solr.psm1
PS C:\projects\sitecore-solr-setup\src> InstallSolr -solrVersion 7.5.0 -solrPort 8975
```

## Guided Uninstall

1. From an elevated powershell prompt run
```
PS C:\projects\sitecore-solr-setup\src> .\uninstall.ps1
```

2. Select the version of Solr you'd like to install
3. Enjoy the show

# References
- https://kamsar.net/index.php/2017/10/Quickly-add-SSL-to-Solr/
