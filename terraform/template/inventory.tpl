all:
  children:
    jenkins:
      hosts:
        jenkins-node:
          ansible_host: ${jenkins_ip}
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
    target:
      hosts:
        target-node:
          ansible_host: ${target_ip}
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_rsa