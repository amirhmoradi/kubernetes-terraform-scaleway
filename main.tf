provider "scaleway" {
  organization = "${var.organization_key}"
  token        = "${var.secret_key}"
  region       = "${var.region}"
}

resource "scaleway_ip" "master_ip" {
  server = "${scaleway_server.cluster_master.id}"
}

data "scaleway_bootscript" "latest_kernel" {
  architecture = "${var.architecture}"
  name_filter  = "x86_64 4.10.8 std"
}

data "scaleway_image" "baseos" {
  architecture = "${var.architecture}"
  name_filter  = "Ubuntu Yakkety"
}

resource "scaleway_server" "cluster_master" {
  name                = "${format("${var.cluster_name}-${var.cluster_os}-master-%02d", count.index)}"
  image               = "${var.base_image_id != "" ? var.base_image_id : data.scaleway_image.baseos.id}"
  type                = "${var.scaleway_master_type}"
  bootscript          = "${var.base_bootscript_id != "" ? var.base_bootscript_id : data.scaleway_bootscript.latest_kernel.id}"
  tags                = ["${var.cluster_name}", "${var.cluster_os}", "${var.cluster_os}-Master"]
  enable_ipv6         = "false"
  dynamic_ip_required = "${var.dynamic_ip}"
  count               = "1"

  connection {
    user        = "${var.user}"
    private_key = "${file(var.user_ssh_key_path)}"
  }

  provisioner "local-exec" {
    command = "rm -rf ./terratemp.scw-install.sh"
  }

  provisioner "local-exec" {
    command = "echo ${format("MASTER_%02d", count.index)}=\"${self.public_ip}\" >> terratemp.ips.txt"
  }

  provisioner "local-exec" {
    command = "echo ${format("MASTER_%02d", count.index)}=\"${self.public_ip}\" >> terratemp.temp_master_ips.txt"
  }

  provisioner "local-exec" {
    command = "${count.index < var.cluster_master_count - 1 ? "echo \"Waiting for all masters\" " : "cp ./terratemp.temp_master_ips.txt ./terratemp.master_ips.txt" }"
  }

  provisioner "local-exec" {
    command = "echo MASTER_PORT=\"${var.cluster_master_port}\" >> terratemp.ips.txt"
  }

  provisioner "local-exec" {
    command = "echo CLUSTER_NAME=\"${var.cluster_name}\" >> terratemp.ips.txt"
  }

  provisioner "local-exec" {
    command = "echo MASTER_SCW_ID=\"${self.id}\" >> terratemp.ips.txt"
  }

  provisioner "local-exec" {
    command = "while [ ! -f ./terratemp.master_ips.txt ]; do sleep 1 && echo 'Waiting for master_ips'; done"
  }

  provisioner "local-exec" {
    command = "./make-files.sh"
  }

  provisioner "local-exec" {
    command = "while [ ! -f ./terratemp.scw-install.sh ]; do sleep 1; done"
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
    command = "scw stop -w ${self.id} && \
              SNAPSHOT_ID=$(scw commit ${self.id}) && \
              echo SNAPSHOT_ID=\"$SNAPSHOT_ID\" >> ./terratemp.ips.txt && \
              BASEIMAGE_ID=$(scw tag --arch=${var.architecture} $SNAPSHOT_ID ${var.cluster_name}_baseimage) && \
              echo BASEIMAGE_ID=\"$BASEIMAGE_ID\" >> ./terratemp.ips.txt && \
              sleep 30 && \
              scw start -w ${self.id} && sleep 60"
  }

  provisioner "file" {
    source      = "./terratemp.scw-install.sh"
    destination = "/tmp/scw-install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "CLUSTER_TOKEN=\"${var.cluster_token}\" bash /tmp/scw-install.sh master",
    ]
  }

  provisioner "local-exec" {
    command = "sleep 300"
  }
}

data "scaleway_image" "baseimage" {
  depends_on   = ["scaleway_server.cluster_master"]
  architecture = "${var.architecture}"
  name_filter  = "${var.cluster_name}"
}

resource "scaleway_server" "cluster_slave" {
  depends_on          = ["scaleway_server.cluster_master"]
  name                = "${format("${var.cluster_name}-${var.cluster_os}-slave-%02d", count.index)}"
  image               = "${data.scaleway_image.baseimage.id}"
  type                = "${var.scaleway_slave_type}"
  bootscript          = "${var.base_bootscript_id != "" ? var.base_bootscript_id : data.scaleway_bootscript.latest_kernel.id}"
  tags                = ["${var.cluster_name}", "${var.cluster_os}", "${var.cluster_os}-Slave"]
  enable_ipv6         = "false"
  dynamic_ip_required = "${var.dynamic_ip}"
  count               = "${var.cluster_slave_count}"

  volume {
    size_in_gb = "${var.scaleway_slave_type == "VC1M" ? 50 : 150}"
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
      "CLUSTER_TOKEN=\"${var.cluster_token}\" bash /tmp/scw-install.sh slave",
    ]
  }
}
