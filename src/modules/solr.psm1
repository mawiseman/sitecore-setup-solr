function InstallSolr {
    [CmdLetBinding()]
    param ( 
        [Parameter(Mandatory = $True)][string]$solrVersion,
        [Parameter(Mandatory = $True)][string]$solrPort
    )
    begin {
        $SolrRoot = "C:\solr\"
        $SolrVersionName = "solr-$solrVersion"
    }
    process {

        # Check Pre-Requisites

        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "Checking Pre-requisites" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green

        ValidateChocolateyInstalled
        ValidateNssmIntalled
        Validate7zInstalled
        ValidateJavaInstalled
        
        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "Installing Solr" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Downloading and extracting" -ForegroundColor Green
        DownloadAndInstallSolr -solrVersion $solrVersion -solrPort $solrPort -solrRoot $SolrRoot -solrVersionName $SolrVersionName
        
        Write-Host ""
        Write-Host "Generating SSL Certificate" -ForegroundColor Green
        TrustSolrSSL -solrRoot $SolrRoot -solrVersionName $SolrVersionName
        
        Write-Host ""
        Write-Host "Validating Install" -ForegroundColor Green
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
        $SolrZipPath = "$solrRoot\$solrVersionName.zip"
    }
    process {

        ### IF SOLR IS INSTALLED RESTART IT

        Write-Host "Attempting to restart existing service '$solrVersionName'"
        try {
            nssm restart $solrVersionName
            
            if($LastExitCode -eq 0) {
                Write-Host "Solr service '$solrVersionName' detected and restarted";
                exit 0;
            }
        }
        catch {
            # ignore error as it indicates service does not exist
            $LastExitCode = 0
        }

        ### ENSURE SOLR DIRECTORY EXISTS

        if (!(Test-Path $solrRoot))
        {
            Write-Host ""
            Write-Host "Creatng Solr root: '$solrRoot'"

            mkdir $solrRoot
        }

        ### DOWNLOAD SOLR INSTALL FILES

        if (!(Test-Path $SolrZipPath))
        {
            Write-Host ""
            Write-Host "Downloading solr zip: $SolrZipPath"

            Invoke-WebRequest -Uri $SolrDownload -OutFile $SolrZipPath
        }

        ### UNPACK SOLR FILES

        $SolrUnpack = "$solrRoot\$solrVersionName"
        if (!(Test-Path $SolrUnpack))
        {
            Write-Host ""
            Write-Host "Extracting solr zip from: $SolrZipPath to: $solrRoot"

            & 7z x "${SolrZipPath}" -o"${solrRoot}" 
        }

        ### INSTALL SOLR SERVICE

        Write-Host ""
        Write-Host "Installing the solr Service: $solrVersionName"

        nssm install "$solrVersionName" "$solrRoot\$solrVersionName\bin\solr.cmd" "-f -p $solrPort"
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

        $KeystoreFile = "$solrRoot\$solrVersionName\server\etc\solr-ssl.keystore.jks";
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
        & $KeyTool -genkeypair -alias solr-ssl -keyalg RSA -keysize 2048 -keypass $KeystorePassword -storepass $KeystorePassword -validity 9999 -keystore $KeystoreFile -ext SAN=DNS:$solrDomain,IP:127.0.0.1 -dname "CN=$solrDomain, OU=Organizational Unit, O=Organization, L=Location, ST=State, C=Country"

        Write-Host ''
        Write-Host 'Generating .p12 to import to Windows...'
        & $KeyTool -importkeystore -srckeystore $KeystoreFile -destkeystore $P12Path -srcstoretype jks -deststoretype pkcs12 -srcstorepass $KeystorePassword -deststorepass $KeystorePassword

        Write-Host ''
        Write-Host 'Trusting generated SSL certificate...'
        $SecureStringKeystorePassword = ConvertTo-SecureString -String $KeystorePassword -Force -AsPlainText
        Import-PfxCertificate -FilePath $P12Path -Password $SecureStringKeystorePassword -CertStoreLocation Cert:\LocalMachine\Root
        
        Write-Host 'SSL certificate is now locally trusted. (added as root CA)'

        UpdateSolrInCmd -solrInCmdPath "$solrRoot\$solrVersionName\bin\solr.in.cmd"

        if($solrDomain -ne "localhost") {
            AddDomainToHosts -ipAddress "127.0.0.1" -domain $solrDomain
        }

        nssm restart $solrVersionName
    }
}

function UpdateSolrInCmd {
    param ( 
        [Parameter(Mandatory = $True)][string]$solrInCmdPath
    )
    begin {

        (Get-Content $solrInCmdPath) | Foreach-Object {
            $_ -replace 'REM set SOLR_SSL_KEY_STORE=etc/solr-ssl.keystore.jks',     'set SOLR_SSL_KEY_STORE=etc/solr-ssl.keystore.jks' `
               -replace 'REM set SOLR_SSL_KEY_STORE_PASSWORD=secret',               'set SOLR_SSL_KEY_STORE_PASSWORD=secret' `
               -replace 'REM set SOLR_SSL_TRUST_STORE=etc/solr-ssl.keystore.jks',   'set SOLR_SSL_TRUST_STORE=etc/solr-ssl.keystore.jks' `
               -replace 'REM set SOLR_SSL_TRUST_STORE_PASSWORD=secret',             'set SOLR_SSL_TRUST_STORE_PASSWORD=secret' `
               -replace 'REM set SOLR_SSL_NEED_CLIENT_AUTH=false',                  'set SOLR_SSL_NEED_CLIENT_AUTH=false' `
               -replace 'REM set SOLR_SSL_WANT_CLIENT_AUTH=false',                  'set SOLR_SSL_WANT_CLIENT_AUTH=false'`
               -replace 'REM set SOLR_SSL_KEY_STORE_TYPE=JKS',                      'set SOLR_SSL_KEY_STORE_TYPE=JKS'`
               -replace 'REM set SOLR_SSL_TRUST_STORE_TYPE=JKS',                    'set SOLR_SSL_TRUST_STORE_TYPE=JKS'
            } | Set-Content $solrInCmdPath
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
                Write-Host $_.Exception.Message -ForegroundColor Red
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

Export-ModuleMember InstallSolr