output "To connect to the API Server and viewing the dashboard copy the configuration locally" {
  value = "scp root@${scaleway_server.cluster_master.public_ip}:/etc/kubernetes/admin.conf ."
}

output "Then to access the Kubernetes dashboard locally run" {
  value = "kubectl --kubeconfig ./admin.conf proxy"
}

output "Use this link to access cluster dashboard" {
  value = "http://localhost:8001/ui/"
}

output "slave-ip" {
  value = "${join(",", scaleway_server.cluster_slave.*.public_ip)}"
}

output "master-ip" {
  value = "${join(",", scaleway_server.cluster_master.public_ip)}"
}
