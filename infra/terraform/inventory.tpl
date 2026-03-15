all:
  children:
    sim_host:
      hosts:
        sitl-server:
          ansible_host: ${sitl_ip}
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ../terraform/sitl-key.pem
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
