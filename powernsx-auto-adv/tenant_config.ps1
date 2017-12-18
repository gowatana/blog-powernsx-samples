# NSX テナント追加スクリプト 付録の設定ファイル。
# テナントの番号を $tenant_no、VM 台数は $vm_num に代入してから読み込む。

# テナント固有 変数
$tenant_id = $tenant_no.toString("000")
$tenant_name = "tenant-" + $tenant_id
$gw_addr = "10.1." + $tenant_no + ".254"
$nw_addr = "10.1." + $tenant_no + ".0"
$tenant_dns = "10.1.1.1"
$nw_msak_length = 24

$dlr_if_name = "if-" + $tenant_name
$dfw_section_name = "dfw-section-" + $tenant_name
$ls_name = "ls-" + $tenant_name

# NSX 環境内で共通の変数
$tz_name = "tz01"
$dlr_id = "edge-5"
$esg_id = "edge-1"
$esg_ext_addr = "192.168.1.144"
$jbox_ip = "192.168.1.223"

$domain_name = "go-lab.jp"
$cluster_name = "nsx-cluster-01"
$datastore_name = "ds_nfs_lab02"

$nw_msak = "255.255.255.0"
$vnic_name = "Network adapter 1"
$template_vm_name = "photon-custom-hw11-2.0-304b817"
$ref_snapshot = "ve-advent-2017" # クリスマスなんで。
