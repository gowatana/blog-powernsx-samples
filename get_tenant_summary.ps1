$tenant_nw_config =  $args[0]
. $tenant_nw_config

function format_output ($title, $object) {
    "=" * 60
    $title
    ""
    ($object | Out-String).Trim()
    ""
}

"#" * 60
"テナント： " + $tenant_name
"実行時刻： " + (Get-Date).DateTime
""

$ls =  Get-NsxTransportZone $tz_name | Get-NsxLogicalSwitch -Name $ls_name
$ls_id = $ls.objectId
$dvpg = $ls | Get-NsxBackingPortGroup
$dlr = Get-NsxLogicalRouter -objectId $dlr_id
$dlr_if = $dlr | Get-NsxLogicalRouterInterface | where {$_.connectedToId -eq $ls_id}
$dlr_if_addr = $dlr_if.addressGroups.addressGroup | %{$_.primaryAddress + "/" + $_.subnetPrefixLength}
$ls_info = $ls | fl `
    name,
    objectId,
    @{N="VDSwitch";E={$dvpg.VDSwitch.Name}},
    @{N="dvPortgroup";E={$dvpg.Name}},
    @{N="DlrIfIPAddress";E={$dlr_if_addr}}
format_output "Tenant Network" $ls_info

$esg = Get-NsxEdge -objectId $esg_id
$nat_original_addr = $nw_addr + "/" + $nw_msak_length
$snat_rule = $esg | Get-NsxEdgeNat | Get-NsxEdgeNatRule |
    where {$_.originalAddress -eq $nat_original_addr}
$snat_rule_info = $snat_rule | fl translatedAddress,originalAddress
format_output "ESG SNAT ルール情報" $snat_rule_info

$dfw_section = Get-NsxFirewallSection -Name $dfw_section_name
$dfw_rules = $dfw_section.rule
$dfw_rules_info = $dfw_rules | select `
    id,
    name,
    @{N="Src";E={
            $member = $_ | Get-NsxFirewallRuleMember |
                where {$_.MemberType -eq "Source"} |
                % {if($_.Name -eq $null){$_.Value}else{$_.Name}
            }
            if(($member).Count -eq 0){$member = "Any"}
            $member
        }
    },
    @{N="Dst";E={
            $member = $_ | Get-NsxFirewallRuleMember |
                where {$_.MemberType -eq "Destination"} |
                % {if($_.Name -eq $null){$_.Value}else{$_.Name}
            }
            if(($member).Count -eq 0){$member = "Any"}
            $member
        }
    },
    @{N="Service";E={$_.services.service.name}},
    action,
    @{N="appliedTo";E={$_.appliedToList.appliedTo.name}},
    logged | ft -AutoSize
format_output ("DFWセクション" + $dfw_section.name + "ルール情報") $dfw_rules_info

# 論理スイッチに接続されているVMの情報
$vms = $ls | Get-NsxBackingPortGroup | Get-VM | sort Name
$vm_info = $vms | % {
    $vm = $_
    $guest = $_ | Get-VmGuest
    $vm | select `
        @{N="VM";E={$_.Name}},
        @{N="HostName";E={$_.Guest.ExtensionData.HostName}},
        @{N="State";E={$_.Guest.State}},
        @{N="IPAddress";E={
                $_.Guest.ExtensionData.Net.IpConfig.IpAddress |
                    where {$_.PrefixLength -le 32} |
                    % {$_.IpAddress + "/" + $_.PrefixLength}
            }
        },
        @{N="Gateway";E={
                $guest_dgw = $_.Guest.ExtensionData.IpStack.IpRouteConfig.IpRoute |
                    where {$_.Network -eq "0.0.0.0"}
                $guest_dgw.Gateway.IpAddress
            }
        },
        @{N="GuestFullName";E={$_.Guest.ExtensionData.GuestFullName}}
} | ft -AutoSize
format_output "VM / ゲスト ネットワーク情報" $vm_info
