output "jenkins_public_ip" {
  value = module.network.jenkins_public_ip
}

output "target_public_ip" {
  value = module.network.target_public_ip
}