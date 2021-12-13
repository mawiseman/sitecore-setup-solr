$SolrServicePrefix = "solr-"

function InstallSolr {
    [CmdLetBinding()]
    param ( 
        [Parameter(Mandatory = $True)][string]$solrVersion,
        [Parameter(Mandatory = $True)][string]$solrPort
    )
    begin {
        $SolrRoot = "C:\solr\"
        $SolrVersionName = $SolrServicePrefix + $solrVersion
    }
    process {
        Write-Host ""
        Write-Host "Installing Solr: $solrVersion on port: $solrPort" -ForegroundColor Green

        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "Checking Pre-requisites" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green

        ValidateChocolateyInstalled
        ValidateNssmIntalled
        Validate7zInstalled
        ValidateJavaInstalled
        
        $serviceExists = ValidateServiceExists -solrVersionName $SolrVersionName
        if($serviceExists) {
            UninstallSolr -solrVersionName $SolrVersionName
        }

        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "Installing Solr" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green

        DownloadAndInstallSolr -solrVersion $solrVersion -solrPort $solrPort -solrRoot $SolrRoot -solrVersionName $SolrVersionName
        
        Write-Host ""
        Write-Host "Generate SSL Certificate" -ForegroundColor Green
        TrustSolrSSL -solrRoot $SolrRoot -solrVersionName $SolrVersionName
        
        Write-Host ""
        Write-Host "Validate Install" -ForegroundColor Green
        ValidateSolr -solrPort $solrPort
    }
}

function ValidateChocolateyInstalled {
    $appName = "choco"

    if (Get-Command $appName -ErrorAction SilentlyContinue) { 
        WriteAppVersion $appName
    }
    else {
        Write-Host "Chocolatey is required. Installing now..." -ForegroundColor Yellow
        
        Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } 
}

function ValidateNssmIntalled {
    $appName = "nssm"

    if (Get-Command $appName -ErrorAction SilentlyContinue) { 
        WriteAppVersion $appName
    }
    else {
        Write-Host "nssm is required. Installing now..." -ForegroundColor Red
        & cinst nssm -y
    } 
}

function Validate7zInstalled {
    $appName = "7z"

    if (Get-Command $appName -ErrorAction SilentlyContinue) 
    { 
        WriteAppVersion $appName
    }
    else {
        Write-Host "7-Zip is required. Installing now..." -ForegroundColor Red
        & cinst 7zip.install -y
    } 
}

function ValidateJavaInstalled {
    
    $Java = GetJavaPath

    # JAVA isn't found, install it

    if($null -eq $Java) {
        Write-Host "Java Runtime is required. Installing now..." -ForegroundColor Red
        & cinst openjdk -y

        exit -1
    }
}

function ValidateServiceExists {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrVersionName
    )
    process {
        $services = GetSolrServices

        if($services.length -gt 0) {
            $services.Contains($solrVersionName)
        }
        else {
            $false
        }
    }
}

function GetJavaPath {
    $java = $null

    # First check for JAVA_HOME

    if($null -ne $Env:JAVA_HOME) {
        $java = $Env:JAVA_HOME
    }

    # Try Manually

    $JavaRoot = "C:\Program Files\Java"

    if($null -eq $java -and (Test-Path $JavaRoot))
    {
        try {
            $javaRoots = Get-ChildItem -Path $JavaRoot -Filter "jre*"

            if($javaRoots.Length -gt 0) {
                $java = ($javaRoots | Select-Object -Last 1).FullName
            }
        }
        catch { }
    }

    # Result

    $java
}

function WriteAppVersion {
    param(
        [Parameter(Mandatory = $True)][string]$appName
    )
    process {
        $app = Get-Command $appName
        Write-Host "$($app.name) v$($app.Version.Major).$($app.Version.Minor).$($app.Version.Build).$($app.Version.Revision)"
    }
}

function DownloadAndInstallSolr {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrVersion,
        [Parameter(Mandatory = $True)][string]$solrPort,
        [Parameter(Mandatory = $True)][string]$solrRoot,
        [Parameter(Mandatory = $True)][string]$solrVersionName
    )
    begin {
        $SolrDownload = "http://archive.apache.org/dist/lucene/solr/$solrVersion/$solrVersionName.zip"
        $SolrZipPath = $(Join-Path $solrRoot $solrVersionName) + '.zip'
    }
    process {

        ### ENSURE SOLR DIRECTORY EXISTS

        if (!(Test-Path $solrRoot))
        {
            Write-Host ""
            Write-Host "Creatng Solr root: '$solrRoot'" -ForegroundColor Green

            mkdir $solrRoot
        }

        ### DOWNLOAD SOLR INSTALL FILES

        if (!(Test-Path $SolrZipPath))
        {
            Write-Host ""
            Write-Host "Downloading solr zip: $SolrZipPath" -ForegroundColor Green

            Invoke-WebRequest -Uri $SolrDownload -OutFile $SolrZipPath
        }

        ### UNPACK SOLR FILES

        $SolrUnpack = "$solrRoot\$solrVersionName"
        if (!(Test-Path $SolrUnpack))
        {
            Write-Host ""
            Write-Host "Extracting solr zip from: $SolrZipPath to: $solrRoot" -ForegroundColor Green

            & 7z x "${SolrZipPath}" -o"${solrRoot}" 
        }

        Write-Host ""
        Write-Host "Installing Solr Service: $solrVersionName" -ForegroundColor Green

        $SolrPath = Join-Path $solrRoot $solrVersionName

        nssm install "$solrVersionName" "$SolrPath\bin\solr.cmd" "-f -p $solrPort"
        nssm start "$solrVersionName"
    }
}

function TrustSolrSSL {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrRoot,
        [Parameter(Mandatory = $True)][string]$solrVersionName,
        [string]$solrDomain = "localhost"
    )
    begin {
        $KeystorePassword = 'secret';
        $Clobber = $True
        $ErrorActionPreference = 'Stop'

        $KeystoreFile = $(Join-Path $solrRoot $solrVersionName) + "\server\etc\solr-ssl.keystore.jks";
    }
    process {
        ### SET UP SSL

        if($KeystorePassword -ne 'secret') {
            Write-Error 'The keystore password must be "secret", because Solr apparently ignores the parameter'
        }

        if((Test-Path $KeystoreFile)) {
            if($Clobber) {
                Write-Host "Removing $KeystoreFile..."
                Remove-Item $KeystoreFile
            } else {
                $KeystorePath = Resolve-Path $KeystoreFile
                Write-Error "Keystore file $KeystorePath already existed. To regenerate it, pass -Clobber."
            }
        }

        $P12Path = [IO.Path]::ChangeExtension($KeystoreFile, 'p12')
        if((Test-Path $P12Path)) {
            if($Clobber) {
                Write-Host "Removing $P12Path..."
                Remove-Item $P12Path
            } else {
                $P12Path = Resolve-Path $P12Path
                Write-Error "Keystore file $P12Path already existed. To regenerate it, pass -Clobber."
            }
        }

        try {
            $Java = GetJavaPath

            $KeyTool = (Get-Command "$Java\bin\keytool.exe").Source
        } catch {
            $KeyTool = Read-Host "keytool.exe not on path. Enter path to keytool (found in JRE bin folder)"

            if([string]::IsNullOrEmpty($KeyTool) -or -not (Test-Path $KeyTool)) {
                Write-Error "Keytool path was invalid."
            }
        }

        Write-Host ''
        Write-Host 'Generating JKS keystore...'
        & $KeyTool -genkeypair -alias $solrVersionName -keyalg RSA -keysize 2048 -keypass $KeystorePassword -storepass $KeystorePassword -validity 9999 -keystore $KeystoreFile -ext SAN=DNS:$solrDomain,IP:127.0.0.1 -dname "CN=$solrDomain, OU=Organizational Unit, O=Organization, L=Location, ST=State, C=Country"

        Write-Host ''
        Write-Host 'Generating .p12 to import to Windows...'
        & $KeyTool -importkeystore -srckeystore $KeystoreFile -destkeystore $P12Path -srcstoretype jks -deststoretype pkcs12 -srcstorepass $KeystorePassword -deststorepass $KeystorePassword

        Write-Host ''
        Write-Host 'Trusting generated SSL certificate...'
        $SecureStringKeystorePassword = ConvertTo-SecureString -String $KeystorePassword -Force -AsPlainText
        Import-PfxCertificate -FilePath $P12Path -Password $SecureStringKeystorePassword -CertStoreLocation Cert:\LocalMachine\Root
        
        Write-Host 'SSL certificate is now locally trusted. (added as root CA)'

        UpdateSolrCmd -solrCmdPath "$solrRoot\$solrVersionName\bin\solr.cmd"
        UpdateSolrInCmd -solrInCmdPath "$solrRoot\$solrVersionName\bin\solr.in.cmd"

        if($solrDomain -ne "localhost") {
            AddDomainToHosts -ipAddress "127.0.0.1" -domain $solrDomain
        }

        nssm restart $solrVersionName
    }
}

function UpdateSolrCmd {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrCmdPath
    )
    begin {
        #remember to escape +, ^ with \+, \^
        (Get-Content $solrCmdPath) | Foreach-Object {
            $_  -replace '-XX:\+UseConcMarkSweepGC \^',     '' `                # In more recent version of the JDK, some parameters are no longer supported
                replace 'if "%%a" GEQ "9" (',               'if %%a GEQ 9 (' `  # https://stackoverflow.com/questions/46125765/java-1-7-or-later-is-required-to-run-solr-but-1-8-installed
            } | Set-Content $solrCmdPath
    }
}

function UpdateSolrInCmd {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrInCmdPath
    )
    begin {

        # Configure SSL

        (Get-Content $solrInCmdPath) | Foreach-Object {
            $_ -replace 'REM set SOLR_SSL_KEY_STORE=etc/solr-ssl.keystore.(jks|p12)',   'set SOLR_SSL_KEY_STORE=etc/solr-ssl.keystore.p12' `
               -replace 'REM set SOLR_SSL_KEY_STORE_PASSWORD=secret',                   'set SOLR_SSL_KEY_STORE_PASSWORD=secret' `
               -replace 'REM set SOLR_SSL_TRUST_STORE=etc/solr-ssl.keystore.(jks|p12)', 'set SOLR_SSL_TRUST_STORE=etc/solr-ssl.keystore.p12' `
               -replace 'REM set SOLR_SSL_TRUST_STORE_PASSWORD=secret',                 'set SOLR_SSL_TRUST_STORE_PASSWORD=secret' `
               -replace 'REM set SOLR_SSL_NEED_CLIENT_AUTH=false',                      'set SOLR_SSL_NEED_CLIENT_AUTH=false' `
               -replace 'REM set SOLR_SSL_WANT_CLIENT_AUTH=false',                      'set SOLR_SSL_WANT_CLIENT_AUTH=false'`
               -replace 'REM set SOLR_SSL_KEY_STORE_TYPE=JKS',                          'set SOLR_SSL_KEY_STORE_TYPE=JKS'`
               -replace 'REM set SOLR_SSL_TRUST_STORE_TYPE=JKS',                        'set SOLR_SSL_TRUST_STORE_TYPE=JKS'
            } | Set-Content $solrInCmdPath

        # Apply log4j hotfix
        # https://solr.apache.org/security.html#apache-solr-affected-by-apache-log4j-cve-2021-44228

        Add-Content $solrInCmdPath ""
        Add-Content $solrInCmdPath "REM Apply log4j hotfix: https://solr.apache.org/security.html#apache-solr-affected-by-apache-log4j-cve-2021-44228"
        Add-Content $solrInCmdPath "set SOLR_OPTS=%SOLR_OPTS% -Dlog4j2.formatMsgNoLookups=true"
        
    }
}

function AddDomainToHosts {
    param ( 
        [Parameter(Mandatory = $True)][string]$ipAddress,
        [Parameter(Mandatory = $True)][string]$domain
    )
    begin {
        $HostsPath = "$env:windir\System32\drivers\etc\hosts"

        $DomainEntry = "$ipAddress $domain"
    }
    process {
        $hosts = Get-Content $HostsPath

        $EntryExists = $hosts | ForEach-Object { if ($_ -match $DomainEntry) { $true } else { $false } } | Sort-Object -unique

        if ($EntryExists -eq $false) {
            Add-Content -Value $DomainEntry -Path $HostsPath
        }
    }
}

function ValidateSolr {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrPort,
        [string]$solrDomain = "localhost",
        [int]$attempts = 5,
        [int]$attemptWait = 30
    )
    begin {
        $SolrUrl = "https://${solrDomain}:${solrPort}"
    }
    process {

        $Attempt = 0
        $StatusCode = 0

        Write-Host "Requesting '$SolrUrl/#'"

        while($Attempt -lt $attempts)
        {
            $Attempt += 1

            Write-Host "Attempt $Attempt/$attempts"

            try
            {
                $WebResponse = Invoke-WebRequest -URI "$SolrUrl" -UseBasicParsing
                $StatusCode = $WebResponse.StatusCode
            }
            catch { 
                Write-Host $_.Exception.Message -ForegroundColor Yellow
                $StatusCode = 500
            }

            if($StatusCode -eq 200) {
                Write-Host "Success" -ForegroundColor Green
                break
            }
            else {
                Write-Host "Waiting $attemptWait secs"
                Start-Sleep $attemptWait
            }
            
        }
    }
}

function GetSolrServices() {
    begin {
        $SolrServiceFilter = $SolrServicePrefix + "*"
    }
    process {
        Get-Service $SolrServiceFilter | Select-Object -ExpandProperty Name
    }
}

function UninstallSolr() {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrVersionName
    )
    process {

        $SolrServiceFolder = nssm get $solrVersionName AppDirectory
        $SolrRootFolder = $SolrServiceFolder -replace "\\bin", ""

        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "Uninstalling Solr" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green

        Write-Host ""
        Write-Host "Stop service: $solrVersionName" -ForegroundColor Green

        nssm stop "$solrVersionName"
        nssm remove "$solrVersionName" confirm

        Write-Host ""
        Write-Host "Delete folder: $SolrRootFolder" -ForegroundColor Green

        Remove-Item -LiteralPath $SolrRootFolder -Force -Recurse

        Write-Host "Removed: $SolrRootFolder"
    }
}

Export-ModuleMember InstallSolr, GetSolrServices, UninstallSolr