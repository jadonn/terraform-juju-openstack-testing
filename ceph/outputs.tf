output "application_names" {
    value = {
        osds = juju_application.ceph_osds.name
        mons = juju_application.ceph_mon.name
        rgw = juju_application.ceph_radosgw.name
    }
}
