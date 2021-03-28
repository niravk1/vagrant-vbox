#!/bin/bash


echo_do() {
  local tmp_file
  local ret_code

  [[ -n "${VERBOSE}" ]] && echo "    $*"
  tmp_file=$(mktemp /var/tmp/cmd_XXXXX.log)
  eval "$@" > "${tmp_file}" 2>&1
  ret_code=$?
  if [[ ${ret_code} -ne 0 ]]; then
    [[ -z "${VERBOSE}" ]] && echo "$@"
    echo "Returned a non-zero code: ${ret_code}" >&2
    echo "Last output lines:" >&2
    tail -5 "${tmp_file}" >&2
    echo "See ${tmp_file} for details" >&2
    exit ${ret_code}
  fi
  rm "${tmp_file}"
}

msg() {
  echo "===== ${*} ====="
}

function repo_setup {
  msg "Configure YUM repos for Oracle EPEL"
  echo_do dnf install -y oracle-epel-release-el8 
} # End repo-setup 

function pkg_install {
  msg "Install all necessary packages required for Ansible and AWX" 
  echo_do dnf install -y git gcc-c++ nodejs python3-pip ansible podman podman-docker podman-compose unzip
  echo_do dnf module install -y container-tools:ol8

} # End pkg_install

function svc_start {
  msg "Enabling and Starting podman service"
  echo_do systemctl enable podman
  echo_do systemctl start podman
} # End svc_start

function aws_podman_compose {
  msg "Clone the podman-compose repo and run podman-compose in detached mode"
  echo_do cd /root ; git clone https://github.com/containers/podman-compose.git
  echo_do cd podman-compose/examples/awx3/
  echo_do podman-compose up --quiet-pull --detach
} # End aws_podman_compose

function display_motd {
  ipadd=`ip address show eth1 | grep -w "inet" | cut -d"/" -f1 | awk '{print $2}'`
  echo -e "podman-compose in detach mode will take ~5 minutes to finish the run"
  echo -e "--------------------------------------" | tee /etc/motd
  echo -e "Login : http://$ipadd:8080" | tee /etc/motd
  echo -e "Username: admin | Password : password" | tee /etc/motd
  echo -e "--------------------------------------" | tee /etc/motd
} # End display_motd

repo_setup 
pkg_install
svc_start
aws_podman_compose
display_motd

