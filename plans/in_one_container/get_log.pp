# @summary Download PIOC django logs from a running container
#
# @param targets A single target to run on (the container host)
# @param container_name Name of target Docker/podman container
# @param container_image Target Docker/podman image
# @param runtime Container runtime executable to use (`undef` = autodetect)
plan pulp3::in_one_container::get_log (
  TargetSpec                    $targets         = 'localhost',
  String[1]                     $user            = system::env('USER'),
  String[1]                     $container_name  = lookup('pulp3::in_one_container::container_name')|$k|{'pulp'},
  String[1]                     $container_image = lookup('pulp3::in_one_container::container_image')|$k|{'pulp/pulp'},
  Optional[Enum[podman,docker]] $runtime         = undef,
  Stdlib::AbsolutePath          $src_path        = lookup('pulp3::in_one_container::django_log')|$k|{'/var/run/django-info.log'},
) {
  $host = run_plan( 'pulp3::in_one_container::get_host', $targets )
  unless run_plan( 'pulp3::in_one_container::match_container', {
    'host'        => $host,
    'name'        => $container_name,
    'image'       => $container_image,
    'all'         => true,
    'runtime_exe' => $host.facts['pioc_runtime_exe']
  }){
    fail_plan( "Cannot find container '${container_name}'" )
  }

  $container = Target.new({
    'name' => $container_name,
    'uri'  => "${host.facts['pioc_runtime_exe']}://${container_name}",
  })


  # download
  # --------------------------------------------------------------------------
  $r = download_file('/var/run/django-info.log','logs', $container)

  $dl_path = $r[0].value['path']

  # sanitize
  # --------------------------------------------------------------------------
  $log_txt = file::read($dl_path)
  $clean_log_lines = $log_txt.split("\n").filter |$x|{
    $x !~ /Header `Correlation-ID` was not found in the incoming request/
  }
  $clean_dl_path = "${dl_path.dirname}/${src_path.basename}.sanitized"
  $w = file::write($clean_dl_path, $clean_log_lines.join("\n"))

  $n = 5
  out::message([
    "\nLast ${n} (sanitized) log lines:\n------------------------------------",
    $clean_log_lines[-1*$n,-1].join("\n"),
    '',
  ].join("\n"))
  out::message("\nLog downloaded to:\n\t${dl_path}\n")
  out::message("\nWrote sanitized log to:\n\t${clean_dl_path}\n\n")
  return($r[0].value['path'])
}
