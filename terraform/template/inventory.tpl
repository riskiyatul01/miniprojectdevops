all:
  children:
    jenkins:
      hosts:
        jenkins-node:
          ansible_host: ${jenkins_ip}
          ansible_user: ubuntu
    target:
      hosts:
        target-node:
          ansible_host: ${target_ip}
          ansible_user: ubuntu