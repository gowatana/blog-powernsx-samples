$tenant_nw_config =  $args[0]
. $tenant_nw_config

# テナント 論理スイッチ作成
$tz = Get-NsxTransportZone -name $tz_name
$ls = New-NsxLogicalSwitch -TransportZone $tz -Name $ls_name
$ls | % {"Logical Switch:　" + $_.name + " => objectId: " + $_.objectId}

# DLR 接続
$dlr = Get-NsxLogicalRouter -objectId $dlr_id
$dlr_if = $dlr | New-NsxLogicalRouterInterface `
    -Type internal -PrimaryAddress $gw_addr -SubnetPrefixLength $nw_msak_length `
    -ConnectedTo $ls -Name $dlr_if_name
$dlr_if | select -ExpandProperty interface |
    % {"DLR Interface: " + $_.name + " => index: " + $_.index}

# SNAT ルール追加
$nat_original_addr = $nw_addr + "/" + $nw_msak_length
$esg = Get-NsxEdge -objectId $esg_id
$snat_rule = $esg | Get-NsxEdgeNat | New-NsxEdgeNatRule `
    -Vnic 0 -action snat `
    -OriginalAddress $nat_original_addr -TranslatedAddress $esg_ext_addr
$snat_rule | % {"SNAT Source Address: " + $_.originalAddress + " => ruleId " + $_.ruleId}

# DFW ルール追加
$dfw_section = New-NsxFirewallSection -Name $dfw_section_name
$dfw_section | % {"DFW Section: " + $_.name + " => id " + $_.id}

$dfw_rule_name = "allow jBox to tenant-ls SSH"
$dfw_section = Get-NsxFirewallSection -objectId $dfw_section.id
$svc = Get-NsxService -Name SSH | where {$_.isUniversal -eq $false}
$dfw_rule = $dfw_section | New-NsxFirewallRule -Name $dfw_rule_name `
    -Action allow -Source $jbox_ip -Destination $ls -Service $svc -AppliedTo $ls
$dfw_rule | % {"DFW Rule: " + $_.name + " => id " + $_.id}

$dfw_rule_name = "allow Any to tenant-ls HTTP"
$dfw_section = Get-NsxFirewallSection -objectId $dfw_section.id
$svc = Get-NsxService -Name HTTP | where {$_.isUniversal -eq $false}
$dfw_rule = $dfw_section | New-NsxFirewallRule -Name $dfw_rule_name `
    -Action allow -Destination $ls -Service $svc -AppliedTo $ls
$dfw_rule | % {"DFW Rule: " + $_.name + " => id " + $_.id}

$vm_folder = Get-Folder -Type VM vm | New-Folder -Name $tenant_name
$vm_folder | % {"VM Folder: " + $_.Name + " => id " + $_.ExtensionData.MoRef.Value}
