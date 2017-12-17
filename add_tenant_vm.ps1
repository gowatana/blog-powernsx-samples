$tenant_nw_config =  $args[0]
. $tenant_nw_config
$tenant_vm_config = $args[1]
. $tenant_vm_config

$ls = Get-NsxTransportZone -name $tz_name | Get-NsxLogicalSwitch -Name $ls_name

"Create Guest OS Customization Spec: " + $os_spec_name
$os_spec_name = "osspec-" + $vm_name
$spec = New-OSCustomizationSpec -Name $os_spec_name `
    -OSType Linux -DnsServer $tenant_dns -Domain $domain_name

"Edit Guest OS Customization Spec: " + $_.Name
$spec | Get-OSCustomizationNicMapping |
    Set-OSCustomizationNicMapping -IpMode UseStaticIP `
    -IpAddress $ip_addr -SubnetMask $nw_msak -DefaultGateway $gw_addr | Out-Null

$vm = Get-Template -Name $template_name |
    New-VM -Name $vm_name -Location (Get-Folder -Type VM $tenant_name) `
    -ResourcePool $cluster_name -Datastore $datastore_name -OSCustomizationSpec $spec
$vm | % {"New VM: " + $_.Name + " => id " + $_.ExtensionData.MoRef.Value}

"Delete Guest OS Customization Spec: " + $spec.Name
$spec | Remove-OSCustomizationSpec -Confirm:$false

"Connect vNIC: " + ($vm.Name + "/" + $vnic_name + " to " + $ls.Name)
$vm | Get-NetworkAdapter -Name $vnic_name | Connect-NsxLogicalSwitch $ls
$vm | Start-VM | % {"Start VM: " + $_.Name}
