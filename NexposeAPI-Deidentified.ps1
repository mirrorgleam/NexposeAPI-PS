# Ignore the SSL certificate error and continue processing anyway because MFing self-signed certs
# Only functional for the instance created by this script
# if you're not using self-signed certs then you can comment out this bit
function Ignore-SelfSignedCerts {
    add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}


function Main
    {
        $Options = @{'1'='CheckEngineStatus'
                     '2'='SimpleXMLRequest'
                     '9'='Logout'}
        ""
        ""
        "Nexpose SCE API Interface"
        $Options
        $MainSelect = Read-Host "Select Option"
            If ($MainSelect -In 1..8)
                {
                Try
                    {
                    &$Options.item($MainSelect)
                    }
                Catch
                    {
                    'nope, try again'
                    Main
                    }
                }
            ElseIf ($MainSelect -eq 9)
                {
                
                }
            Else
                {
                '
                
Check your selection and try again
                
                
                '
                Main
                }
    }



# Collects NSC credentials from user then verifies their validity
function CollectStaticData
    {
        $Global:Creds = Get-Credential -Message "Nexpose Login Credentials"
        $Global:NSCLocation = Read-Host "IP/URL for your NSC"
        $Global:NSCPort = Read-Host "Port for connection to NSC"
        $Global:APIVersion = Read-Host "Version of API to use (1.1 or 1.2)"
        
        $LoginBody = "<?xml version='1.0' encoding='UTF-8'?>`n<LoginRequest sync-id='artibrary_integer' user-id='$($Global:Creds.GetNetworkCredential().UserName)' password='$($Global:Creds.GetNetworkCredential().Password)'/>"

        $LoginRequest = Invoke-WebRequest -Uri "$($Global:NSCLocation):$($Global:NSCPort)/api/$($Global:APIVersion)/xml" -Headers @{"Content-Type"="text/xml"} -Method Post -Body $LoginBody

        If ($LoginRequest.AllElements.success.Contains('0'))
            {
            $wshell1 = New-Object -ComObject Wscript.Shell
            $TA = $wshell1.Popup("Login Failed, Try Again?",0,"Nexpose",1)
                If ($TA -eq 1)
                    {
                    CollectStaticData
                    }
                Else
                    {
                    exit
                    }
            }
        
        Elseif ($LoginRequest.AllElements.success.Contains('1'))
            {
                "Login Successful"
            }

        Else 
            {
                'no'
            }
    }

# Logout of NSC API
function Logout
    {
        GetSessionID

        $LogoutBody = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<LogoutRequest session-id=`"$($Global:SesID)`"/>"
        
        $LogoutResp = Invoke-WebRequest -Uri "$($Global:NSCLocation):$($Global:NSCPort)/api/$($Global:APIVersion)/xml" -Headers @{"Content-Type" = "text/xml"} -Method Post -Body $LogoutBody
    
        exit
    }


# Get initial or new Session-ID as needed for interaction with NSC API
function GetSessionID
    {
        $LoginBody = "<?xml version='1.0' encoding='UTF-8'?>
            <LoginRequest sync-id='artibrary_integer' user-id='"+$Global:creds.GetNetworkCredential().UserName+"' password='"+$Global:creds.GetNetworkCredential().Password+"'/>"
        
        $LoginResp = Invoke-WebRequest -Uri "$($Global:NSCLocation):$($Global:NSCPort)/api/$($Global:APIVersion)/xml" -Headers @{"Content-Type" = "text/xml"} -Method Post -Body $LoginBody

        $Global:SesID = $LoginResp.BaseResponse.Cookies.value

        #"Your session ID is "+$SesID+" thank you." # remove comment for troubleshooting
    }


# Get list of scan engines
function CheckEngineStatus
    {
        GetSessionID        $EngListBody = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<EngineListingRequest session-id=`"$($Global:SesID)`">`n</EngineListingRequest>"                $EngList = Invoke-WebRequest -Uri "$($Global:NSCLocation):$($Global:NSCPort)/api/$($Global:APIVersion)/xml" -Headers @{"Content-Type" = "text/xml"} -Method Post -Body $EngListBody        $EngList.AllElements |where{$_.name -ne $null} |Select-Object -property name, status |Sort name, status |Out-GridView -Title 'Scan Engine List'        Main    }


# Easier posting of xml commands to NSC API to enable quicker discovery of data available within each
function SimpleXMLRequest
    {
        GetSessionID        <#                This commented block was used to direct output of data to a file        I am instead, for the time being, going to direct it all to Out-Gridview        Easier for quick testing and verification of results        $UserPath = $null        $UserPath = Read-Host "Folder path to export file"                        While ((Test-Path $UserPath) -ne 'True')                {                $wshell2 = New-Object -ComObject Wscript.Shell
                $TP = $wshell2.Popup($UserPath+'is not a valid path, Try Again?',0,'Nexpose',1)                                        If ($TP -eq 1)                        {                        SimpleXMLRequest                        }                                        Else                        {                        Main                        }                }#>#        $RequestOptions = Write-Host     #going to have the options that can be selected for SimpleXMLRequest displayed here        $RequestType = Read-Host "Input Request Type"#        $ReqExpPath = $UserPath+$RequestType+'.csv'           # part of the above comment block        $ReqTestBody = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<$($RequestType) session-id=`"$($Global:SesID)`">`n</$($RequestType)>"                $ReqTestResp = Invoke-WebRequest -Uri "$($Global:NSCLocation):$($Global:NSCPort)/api/$($Global:APIVersion)/xml" -Headers @{"Content-Type" = "text/xml"} -Method Post -Body $ReqTestBody        $ReqTestResp.AllElements |Out-GridView        Main    }



Ignore-SelfSignedCerts
CollectStaticData
Main

