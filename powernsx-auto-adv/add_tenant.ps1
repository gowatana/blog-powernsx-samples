# NSX テナント追加スクリプト
# 実行方法：
#   PowerNSX> .\add_tenant.ps1 ＜設定ファイル＞ ＜テナント No＞ ＜VM 台数＞
# 実行例：
#   PowerNSX> .\add_tenant.ps1 .\tenant_config.ps1 55 3

# テナントの設定ファイルを指定。
$tenant_nw_config =  $args[0]

# テナントの ID を指定
$tenant_no = $args[1] #1～254

# VM 台数。
$vm_num = $args[2]

# テナントの設定を読み込み。
. $tenant_nw_config

$os_spec_name = "guest-os-spec-" + $tenant_name

# ------------------------------
"■ テナント作成: " + $tenant_name

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

# ------------------------------
"▼ VM 作成"

#$ls = Get-NsxTransportZone -name $tz_name | Get-NsxLogicalSwitch -Name $ls_name
$src_vm = Get-VM -Name $template_vm_name
$snapshot = $src_vm | Get-Snapshot -Name $ref_snapshot

"Create Guest OS Customization Spec: " + $os_spec_name
$spec = New-OSCustomizationSpec -Name $os_spec_name `
    -OSType Linux -DnsServer $tenant_dns -Domain $domain_name

# VM を作成。
$vm_count = 0
while($vm_num -gt 0){
    $vm_count = $vm_count + 1
    $vm_id = $vm_count.ToString("000")

    $vm_name = "vm-" + $tenant_id + "-" + $vm_id
    $ip_addr = "10.1." + $tenant_no + "." + $vm_count

    "Edit Guest OS Customization Spec: " + $_.Name
    $spec | Get-OSCustomizationNicMapping |
        Set-OSCustomizationNicMapping -IpMode UseStaticIP `
        -IpAddress $ip_addr -SubnetMask $nw_msak -DefaultGateway $gw_addr | Out-Null

    $vm = $src_vm |
        New-VM -Name $vm_name -Location (Get-Folder -Type VM $tenant_name) `
        -LinkedClone -ReferenceSnapshot $snapshot `
        -ResourcePool $cluster_name -Datastore $datastore_name -OSCustomizationSpec $spec
    $vm | % {"New VM: " + $_.Name + " => id " + $_.ExtensionData.MoRef.Value}

    "Connect vNIC: " + ($vm.Name + "/" + $vnic_name + " to " + $ls.Name)
    $vm | Get-NetworkAdapter -Name $vnic_name | Connect-NsxLogicalSwitch $ls
    $vm | Start-VM | % {"Start VM: " + $_.Name}

    $vm_num = $vm_num - 1
}

"Delete Guest OS Customization Spec: " + $spec.Name
$spec | Remove-OSCustomizationSpec -Confirm:$false
