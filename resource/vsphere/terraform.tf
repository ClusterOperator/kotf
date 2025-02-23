{{ $provider := .provider }}
{{ $region := .cloudRegion }}
{{ $hosts := .hosts }}

variable "username" {
  type = string
}

variable "password" {
   type = string
}

provider "vsphere" {
  user = var.username
  password = var.password
  vsphere_server = "{{ $provider.host }}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "{{ $region.datacenter }}"
}
{{ range $region.zones}}

{{ if .cluster }}

data "vsphere_resource_pool" "{{ .key }}" {
  {{ if  eq .resourcePool "Resources" }}
   name  = "{{ .cluster }}/Resources"
  {{ else if ne .resourcePool "Resources" }}
   name  = "{{ .cluster }}/Resources/{{ .resourcePool }}"
  {{ end }}
   datacenter_id = data.vsphere_datacenter.dc.id
}

{{ end }}

{{ if .resource }}

data "vsphere_resource_pool" "{{ .key }}" {
   name  = "{{ .resource }}"
   datacenter_id = data.vsphere_datacenter.dc.id
}

{{ end }}

{{ if .resourceType }}
    {{ if  eq .resourceType "host" }}
data "vsphere_host" "{{ .key }}" {
  name          = "{{ .hostSystem }}"
  datacenter_id = data.vsphere_datacenter.dc.id
}
    {{ end }}
{{ end }}


data "vsphere_network" "{{ .key }}" {
  name = "{{ .network }}"
  datacenter_id = data.vsphere_datacenter.dc.id
}


{{ if .stores }}
 {{ range $key, $val := .stores}}
 data "vsphere_datastore" "{{ $val }}" {
   name = "{{ $key }}"
   datacenter_id = data.vsphere_datacenter.dc.id
 }
{{ end }}
{{ else }}

{{ range .datastore}}
data "vsphere_datastore" "{{ . }}" {
  name = "{{ . }}"
  datacenter_id = data.vsphere_datacenter.dc.id
}
{{ end }}

{{ end }}


data "vsphere_virtual_machine" "{{ .key }}" {
  name = "{{ .imageName }}"
  datacenter_id = data.vsphere_datacenter.dc.id
}
{{ end }}


{{ range $hosts}}
resource "vsphere_virtual_machine" "{{.shortName}}" {
  name = "{{ .name }}"
  folder = "kubeoperator"
  resource_pool_id = data.vsphere_resource_pool.{{ .zone.key }}.id

{{ if .zone.resourceType }}
  {{ if eq .zone.resourceType "host" }}
    host_system_id = data.vsphere_host.{{ .zone.key }}.id
  {{ end }}
{{ end }}

  {{ if .datastoreKey}}
    datastore_id = data.vsphere_datastore.{{ .datastoreKey }}.id
  {{ else if .datastore }}
    datastore_id = data.vsphere_datastore.{{ .datastore }}.id
  {{ else }}
     datastore_id = data.vsphere_datastore.{{ index .zone.stores 0 }}.id
  {{ end }}


  num_cpus = {{ .cpu }}
  memory = {{ .memory }}
  guest_id = data.vsphere_virtual_machine.{{ .zone.key }}.guest_id
  scsi_type = data.vsphere_virtual_machine.{{ .zone.key }}.scsi_type

  network_interface {
    network_id = data.vsphere_network.{{ .zone.key }}.id
  }


  {{ if not .zone.imageDisks }}
    disk {
      label            = "disk0"
      size             = data.vsphere_virtual_machine.{{ .zone.key }}.disks.0.size
      eagerly_scrub    = data.vsphere_virtual_machine.{{ .zone.key }}.disks.0.eagerly_scrub
      thin_provisioned = data.vsphere_virtual_machine.{{ .zone.key }}.disks.0.thin_provisioned
    }
  {{ else }}
    {{ $key := .zone.key}}
    {{ range $i, $v := .zone.imageDisks }}
        disk {
          label            = "disk{{ $i }}"
          size             = data.vsphere_virtual_machine.{{ $key }}.disks.{{ $i }}.size
          eagerly_scrub    = data.vsphere_virtual_machine.{{ $key }}.disks.{{ $i }}.eagerly_scrub
          thin_provisioned = data.vsphere_virtual_machine.{{ $key }}.disks.{{ $i }}.thin_provisioned
      {{if gt $i 0}}
           unit_number = {{ $i }}
      {{end}}
        }
    {{ end }}
  {{ end }}



  lifecycle {
    ignore_changes = all
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.{{ .zone.key }}.id
    timeout = 60
    customize {

      linux_options {
        host_name = "{{ .shortName }}"
        domain = ""
      }

      network_interface {
        ipv4_address = "{{ .ip }}"
        ipv4_netmask = "{{ .zone.netMask }}"
      }
      ipv4_gateway = "{{ .zone.gateway}}"
      dns_server_list = [ "{{ .zone.dns1 }}", "{{ .zone.dns2 }}"]
    }
  }
}
{{ end }}