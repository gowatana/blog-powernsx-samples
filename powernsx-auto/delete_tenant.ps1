$tenant_nw_config =  $args[0]
. $tenant_nw_config

$ls = Get-NsxTransportZone $tz_name | Get-NsxLogicalSwitch -Name $ls_name

"Remove VM"
$ls | Get-NsxBackingPortGroup | Get-VM | Stop-VM -Confirm:$false | Out-Null
$ls | Get-NsxBackingPortGroup | Get-VM | Remove-VM -DeletePermanently -Confirm:$false

"Remove DFW Rule"
Get-NsxFirewallSection -Name $dfw_section_name |
    Remove-NsxFirewallSection -force -Confirm:$false

"Remove SNAT Rule"
$nat_original_addr = $nw_addr + "/" + $nw_msak_length
Get-NsxEdge -objectId $esg_id | Get-NsxEdgeNat | Get-NsxEdgeNatRule |
    where {$_.originalAddress -eq $nat_original_addr} |
    Remove-NsxEdgeNatRule -Confirm:$false

"Remove NsxLogical Switch"
Get-NsxLogicalRouter -objectId $dlr_id | Get-NsxLogicalRouterInterface |
    where {$_.connectedToId -eq $ls.objectId} |
    Remove-NsxLogicalRouterInterface -Confirm:$false
$ls | Remove-NsxLogicalSwitch -Confirm:$false

"Remove VM Folder"
Get-Folder -Type VM $tenant_name | Remove-Folder -Confirm:$false
