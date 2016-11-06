variable "user" {}
variable "key_path" {}
variable "consul_server_count" {}
variable "subnet_id" {}
variable "xlb_sg_id" {}
variable "atlas_token" {}
variable "atlas_username" {}

data "atlas_artifact" "consul-vault-seal" {
  name = "bgreen/consul-vault-seal"
  type = "amazon.image"
  build = "latest"
}


data "template_file" "vault_conf" {
  template = "${path.module}/scripts/vault_conf.sh.tpl"
  vars {
    atlas_token             = "${var.atlas_token}"
    atlas_username          = "${var.atlas_username}"
  }
}

resource "aws_instance" "consul-vault" {
    ami = "${data.atlas_artifact.consul-vault-seal.metadata_full.region-us-east-1}"
    instance_type = "t2.micro"
    count = "${var.consul_server_count}"
    subnet_id = "${var.subnet_id}"
    vpc_security_group_ids = ["${var.xlb_sg_id}"]
    tags = {
      env = "xlb-demo"
    }
    connection {
        user = "${var.user}"
        private_key = "${var.key_path}"
    }

    provisioner "remote-exec" {
        inline = [
            "echo ${var.consul_server_count} > /tmp/consul-server-count",
            "echo ${aws_instance.consul-vault.0.private_dns} > /tmp/consul-server-addr",
        ]
    }

    provisioner "remote-exec" {
        scripts = [
            "${path.module}/scripts/install.sh"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "sudo systemctl enable consul.service",
            "sudo systemctl start consul"
        ]
    }

    provisioner "remote-exec" {
      inline = ["${data.template_file.vault_conf.rendered}"]
    }

    provisioner "remote-exec" {
        inline = [
            "sudo systemctl enable vault.service",
            "sudo systemctl start vault"
        ]
    }    
}
