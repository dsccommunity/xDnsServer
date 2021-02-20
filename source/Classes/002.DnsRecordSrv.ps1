<#
    .SYNOPSIS
        A DSC Resource for MS DNS Server that represents an SRV resource record.
    .PARAMETER SymbolicName
        Service name for the SRV record. eg: xmpp, ldap, etc. (Key Parameter)
    .PARAMETER Protocol
        Service transmission protocol ('TCP' or 'UDP') (Key Parameter)
    .PARAMETER Port
        The TCP or UDP port on which the service is found (Key Parameter)
    .PARAMETER Target
        Specifies the Target Hostname or IP Address. (Key Parameter)
    .PARAMETER Priority
        Specifies the Priority value of the SRV record. (Mandatory Parameter)
    .PARAMETER Weight
        Specifies the weight of the SRV record. (Mandatory Parameter)
    .PARAMETER ZoneName
        Specifies the name of a DNS zone. (Key Parameter)
    .PARAMETER TimeToLive
        Specifies the TimeToLive value of the SRV record. Value must be in valid TimeSpan string format (i.e.: Days.Hours:Minutes:Seconds.Miliseconds or 30.23:59:59.999).
    .PARAMETER DnsServer
        Name of the DnsServer to create the record on.
    .PARAMETER Ensure
        Whether the host record should be present or removed.
#>

$script:localizedDataDnsRecordSrv = Get-LocalizedData -DefaultUICulture en-US -FileName 'DnsRecordSrv.strings.psd1'

[DscResource()]
class DnsRecordSrv : DnsRecordBase
{
    [DscProperty(Key)]
    [System.String] $SymbolicName

    [DscProperty(Key)]
    [ValidateSet('TCP', 'UDP')]
    [System.String] $Protocol

    [DscProperty(Key)]
    [ValidateRange(1, 65535)]
    [System.UInt16] $Port

    [DscProperty(Key)]
    [System.String] $Target

    [DscProperty(Mandatory)]
    [System.UInt16] $Priority

    [DscProperty(Mandatory)]
    [System.UInt16] $Weight

    hidden [string] getRecordHostName() {
        return "_$($this.SymbolicName)._$($this.Protocol)".ToLower()
    }

    hidden [ciminstance] GetResourceRecord()
    {
        $recordHostName = $this.getRecordHostName()

        Write-Verbose -Message ($script:localizedDataDnsRecordSrv.GettingDnsRecordMessage -f $recordHostName, $this.target, 'SRV', $this.Zone, $this.DnsServer)

        $dnsParameters = @{
            Name         = $recordHostName
            ZoneName     = $this.ZoneName
            ComputerName = $this.DnsServer
            RRType       = 'SRV'
        }

        $record = Get-DnsServerResourceRecord @dnsParameters -ErrorAction SilentlyContinue | Where-Object {
            $_.HostName -eq $recordHostName -and
            $_.RecordData.Port -eq $this.Port -and
            $_.RecordData.DomainName -eq "$($this.Target)."
        }

        return $record
    }

    hidden [DnsRecordSrv] NewDscResourceObjectFromRecord([ciminstance] $record)
    {
        $dscResourceObject = [DnsRecordSrv]::new()

        $dscResourceObject.ZoneName     = $this.ZoneName
        $dscResourceObject.SymbolicName = $this.SymbolicName
        $dscResourceObject.Protocol     = $this.Protocol.ToLower()
        $dscResourceObject.Port         = $this.Port
        $dscResourceObject.Target       = ($record.RecordData.DomainName).TrimEnd('.')
        $dscResourceObject.Priority     = $record.RecordData.Priority
        $dscResourceObject.Weight       = $record.RecordData.Weight
        $dscResourceObject.TimeToLive   = $record.TimeToLive.ToString()
        $dscResourceObject.DnsServer    = $this.DnsServer
        $dscResourceObject.Ensure       = 'Present'

        return $dscResourceObject
    }

    hidden [void] AddResourceRecord()
    {
        $recordHostName = $this.getRecordHostName()

        $dnsParameters = @{
            ZoneName     = $this.ZoneName
            ComputerName = $this.DnsServer
            Name = $recordHostName
            Srv = $true
            DomainName = $this.Target
            Port = $this.Port
            Priority = $this.Priority
            Weight = $this.Weight
        }

        if ($null -ne $this.TimeToLive)
        {
            $dnsParameters.Add('TimeToLive', $this.TimeToLive)
        }

        Write-Verbose -Message ($script:localizedDataDnsRecordSrv.CreatingDnsRecordMessage -f 'SRV', $recordHostName, $this.Target, $this.ZoneName, $this.DnsServer)

        Add-DnsServerResourceRecord @dnsParameters
    }
}