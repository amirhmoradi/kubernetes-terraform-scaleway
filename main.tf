provider "scaleway" {
  organization = "${var.organization_key}"
  token        = "${var.secret_key}"
  region       = "${var.region}"
}

#resource "scaleway_ip" "master_ip" {
#  server = "${scaleway_server.cluster_master.id}"
#}
resource "scaleway_ip" "cluster_public_ip" {
  #server = "${scaleway_server.cluster_master.id}"  #count = 1
}

data "scaleway_bootscript" "latest_kernel" {
  architecture = "${var.architecture}"
  name_filter  = "x86_64 4.10.8 std"
}

data "scaleway_image" "baseos" {
  architecture = "${var.architecture}"
  name_filter  = "Ubuntu Yakkety"
}

data "scaleway_image" "baseimage" {
  depends_on   = ["scaleway_server.cluster_master"]
  architecture = "${var.architecture}"
  name_filter  = "${var.cluster_name}"
}

##### Security Group
##### TODO: Modularize this section
resource "scaleway_security_group" "cluster-sg" {
  name        = "cluster-sg"
  description = "cluster-sg"
}

resource "scaleway_security_group_rule" "accept-internal" {
  security_group = "${scaleway_security_group.cluster-sg.id}"

  action    = "accept"
  direction = "inbound"

  # NOTE this is just a guess - might not work for you.
  ip_range = "${cidrhost("${scaleway_server.cluster_master.private_ip}/16", 0)}/16"
  protocol = "TCP"
  port     = "${element(var.cluster_master_port, count.index)}"
  count    = "${length(var.cluster_master_port)}"
}

resource "scaleway_security_group_rule" "ssh_accept" {
  security_group = "${scaleway_security_group.cluster-sg.id}"
  action         = "accept"
  direction      = "inbound"
  ip_range       = "176.169.148.253"
  protocol       = "TCP"
  port           = 22
  depends_on     = ["scaleway_security_group_rule.accept-internal"]
}

resource "scaleway_security_group_rule" "master_ports_accept" {
  security_group = "${scaleway_security_group.cluster-sg.id}"
  action         = "accept"
  direction      = "inbound"
  ip_range       = "176.169.148.253"
  protocol       = "TCP"
  port           = "${element(var.cluster_master_port, count.index)}"
  count          = "${length(var.cluster_master_port)}"
  depends_on     = ["scaleway_security_group_rule.accept-internal"]
}

resource "scaleway_security_group_rule" "drop-external" {
  security_group = "${scaleway_security_group.cluster-sg.id}"

  action    = "drop"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"

  port  = "${element(var.cluster_master_port, count.index)}"
  count = "${length(var.cluster_master_port)}"

  depends_on = ["scaleway_security_group_rule.accept-internal"]
}

##### End Security Group

resource "scaleway_server" "cluster_master" {
  name        = "${format("${var.cluster_name}-${var.cluster_os}-master-%02d", count.index)}"
  image       = "${var.base_image_id != "" ? var.base_image_id : data.scaleway_image.baseos.id}"
  type        = "${var.scaleway_master_type}"
  bootscript  = "${var.base_bootscript_id != "" ? var.base_bootscript_id : data.scaleway_bootscript.latest_kernel.id}"
  tags        = ["${var.cluster_name}", "${var.cluster_os}", "${var.cluster_os}-Master"]
  enable_ipv6 = "false"

  #dynamic_ip_required = "${var.dynamic_ip}"
  public_ip = "${scaleway_ip.cluster_public_ip.ip}"
  count     = "1"

  connection {
    user        = "${var.user}"
    private_key = "${file(var.user_ssh_key_path)}"
    agent       = false
  }

  provisioner "local-exec" {
    command = <<-EOD
      rm -rf ./terratemp.scw-install.sh
      echo ${format("MASTER_%02d", count.index)}=\"${self.public_ip != "" ? self.public_ip : self.private_ip}\" >> terratemp.ips.txt
      echo ${format("MASTER_%02d", count.index)}=\"${self.public_ip != "" ? self.public_ip : self.private_ip}\" >> terratemp.temp_master_ips.txt
      ${count.index < var.cluster_master_count - 1 ? "echo \"Waiting for all master\" " : "cp ./terratemp.temp_master_ips.txt ./terratemp.master_ips.txt" }
      echo ${format("MASTER_%02d", count.index)}_PORT=\"${element(var.cluster_master_port, count.index)}\" >> terratemp.ips.txt
      echo CLUSTER_NAME=\"${var.cluster_name}\" >> terratemp.ips.txt
      echo ${format("MASTER_%02d", count.index)}_SCW_ID=\"\"${self.id}\"\" >> terratemp.ips.txt
      while [ ! -f ./terratemp.master_ips.txt ]; do sleep 1 && echo 'Waiting for master_ips'; done
      ./make-files.sh
      while [ ! -f ./terratemp.scw-install.sh ]; do sleep 1; done
      EOD
  }

  provisioner "file" {
    source      = "./terratemp.prep-sys-ubuntu.sh"
    destination = "/tmp/prep-sys-ubuntu.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /tmp/prep-sys-ubuntu.sh",
    ]
  }

  provisioner "local-exec" {
    command = <<-EOD
      if [ -f ./terratemp.baseimage-id.txt ]; then exit 0; else echo "preparing snapshot of the server" && \
      sleep 30 && \
      scw stop -w ${self.id} && \
      SNAPSHOT_ID=$(scw commit ${self.id}) && \
      echo SNAPSHOT_ID=\"$SNAPSHOT_ID\" >> ./terratemp.ips.txt && \
      BASEIMAGE_ID=$(scw tag --arch=${var.architecture} $SNAPSHOT_ID ${var.cluster_name}_baseimage) && \
      echo BASEIMAGE_ID=\"$BASEIMAGE_ID\" >> ./terratemp.ips.txt && \
      echo $BASEIMAGE_ID > ./terratemp.baseimage-id.txt
      sleep 120 && scw start -w ${self.id} && sleep 120; fi
      EOD
  }

  provisioner "file" {
    source      = "./terratemp.scw-install.sh"
    destination = "/tmp/scw-install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "CLUSTER_TOKEN=\"${var.cluster_token}\" bash /tmp/scw-install.sh k8s-master",
    ]
  }

  provisioner "local-exec" {
    command = "sleep 120"
  }
}

resource "scaleway_server" "cluster_agent" {
  depends_on          = ["scaleway_server.cluster_master"]
  name                = "${format("${var.cluster_name}-${var.cluster_os}-agent-%02d", count.index)}"
  image               = "${data.scaleway_image.baseimage.id}"
  type                = "${var.scaleway_agent_type}"
  bootscript          = "${var.base_bootscript_id != "" ? var.base_bootscript_id : data.scaleway_bootscript.latest_kernel.id}"
  tags                = ["${var.cluster_name}", "${var.cluster_os}", "${var.cluster_os}-agent"]
  enable_ipv6         = "false"
  dynamic_ip_required = "${var.dynamic_ip}"
  count               = "${var.cluster_agent_count}"

  # NB: VC1S and C1 types do not support volume edition, you should remove this block manually.
  volume {
    size_in_gb = "${var.scaleway_agent_type == "VC1M" ? 50 : 150}"
    type       = "l_ssd"
  }

  connection {
    user        = "${var.user}"
    private_key = "${file(var.user_ssh_key_path)}"
  }

  provisioner "local-exec" {
    command = "while [ ! -f ./terratemp.scw-install.sh ]; do sleep 1; done"
  }

  provisioner "file" {
    source      = "./terratemp.scw-install.sh"
    destination = "/tmp/scw-install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "CLUSTER_TOKEN=\"${var.cluster_token}\" bash /tmp/scw-install.sh k8s-agent",
    ]
  }
}
