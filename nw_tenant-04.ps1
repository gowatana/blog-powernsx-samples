# テナント固有 変数
$tenant_name = "tenant-04"
$gw_addr = "10.1.40.1"
$nw_addr = "10.1.40.0"
$nw_msak_length = 24

# 共通 変数
$tz_name = "tz01"
$dlr_id = "edge-5"
$esg_id = "edge-1"
$esg_ext_addr = "192.168.1.144"
$jbox_ip = "192.168.1.223"

$dlr_if_name = "if-" + $tenant_name
$dfw_section_name = "dfw-section-" + $tenant_name
$ls_name = "ls-" + $tenant_name
