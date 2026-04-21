# Ansible — Configuration as Code

Direktori ini berisi semua konfigurasi **Ansible** untuk otomasi provisioning dan deployment pada infrastruktur CI/CD pipeline Miniproject DevOps Kelompok 3.

## 📁 Struktur Direktori

```
ansible/
├── ansible.cfg                  # Konfigurasi global Ansible
├── playbook-setup-all.yml       # Setup awal semua VM (sekali jalan)
├── playbook-deploy.yml          # Deploy aplikasi ke target node
├── playbook-verify.yml          # Verifikasi status semua node
├── inventory/
│   └── hosts.yml                # Daftar host (Jenkins + Target)
├── group_vars/
│   ├── all.yml                  # Variabel global (semua node)
│   ├── jenkins.yml              # Variabel khusus Jenkins node
│   └── target.yml               # Variabel khusus Target node
└── roles/
    ├── common/                  # Paket dasar & konfigurasi OS
    │   ├── defaults/main.yml
    │   └── tasks/main.yml
    ├── docker/                  # Instalasi Docker Engine
    │   ├── defaults/main.yml
    │   ├── tasks/main.yml
    │   └── handlers/main.yml
    ├── jenkins/                 # Setup Jenkins + JCasC
    │   ├── defaults/main.yml
    │   ├── tasks/main.yml
    │   ├── files/plugins.txt
    │   └── templates/jenkins-casc.yml.j2
    └── deploy/                  # Deployment via Docker Compose
        ├── defaults/main.yml
        ├── tasks/main.yml
        ├── handlers/main.yml
        └── templates/docker-compose.yml.j2
```

## 🚀 Cara Penggunaan

### Prerequisite

1. **SSH Key** — Pastikan SSH key (`~/.ssh/id_rsa`) sudah terkonfigurasi dan bisa akses ke semua VM
2. **Ansible** — Install Ansible di mesin kontrol (`pip install ansible`)
3. **Python** — Python 3.x terinstall di semua target node

### 1. Setup Awal (Sekali Jalan)

Menjalankan konfigurasi awal pada semua VM: install paket dasar, Docker Engine, Jenkins, dan persiapan target node.

```bash
cd ansible/
ansible-playbook playbook-setup-all.yml
```

**Yang dikonfigurasi:**
| Play | Host | Role | Keterangan |
|------|------|------|------------|
| 1 | All | `common` + `docker` | Paket dasar + Docker Engine |
| 2 | Jenkins | `jenkins` | Jenkins container + JCasC + Plugins + Ansible CLI |
| 3 | Target | (inline tasks) | Direktori deployment |

### 2. Deploy Aplikasi

Dipanggil otomatis oleh Jenkins pipeline, atau bisa manual:

```bash
ansible-playbook playbook-deploy.yml \
  -e "image_tag=build-42" \
  -e "dockerhub_password=YOUR_PASSWORD"
```

### 3. Verifikasi Status

Cek apakah semua node terkonfigurasi dengan benar:

```bash
ansible-playbook playbook-verify.yml
```

## 🏗️ Arsitektur

```
┌─────────────────┐       Ansible         ┌──────────────────┐
│  Control Node   │ ───────────────────>  │  Jenkins Node    │
│  (Lokal/CI)     │                       │  4.194.56.40     │
└─────────────────┘                       │  - Docker        │
        │                                 │  - Jenkins (JCasC)│
        │                                 │  - Ansible CLI   │
        │                                 └────────┬─────────┘
        │                                          │
        │         Ansible                          │ Pipeline triggers
        │ ───────────────────>             ansible-playbook
        │                                          │
        │                                          ▼
        │                                 ┌──────────────────┐
        └───────────────────────────────> │  Target Node     │
                                          │  20.205.234.122  │
                                          │  - Docker        │
                                          │  - App Container │
                                          │  - Docker Compose│
                                          └──────────────────┘
```

## 🔐 Keamanan

### Secrets Management

Pada environment **production**, gunakan **Ansible Vault** untuk menyimpan credential:

```bash
# Buat file vault
ansible-vault create group_vars/vault.yml

# Edit file vault
ansible-vault edit group_vars/vault.yml

# Jalankan playbook dengan vault
ansible-playbook playbook-setup-all.yml --ask-vault-pass
```

Variabel yang harus dipindahkan ke vault di production:
- `jenkins_admin_password`
- `dockerhub_password`
- SSH private keys

### Konfigurasi Saat Ini (Lab/Akademis)

Untuk kemudahan demonstrasi, credentials disimpan plaintext di `group_vars/jenkins.yml` dengan penjelasan vault di komentar file tersebut.

## 📋 Roles

### `common`
- Update apt cache
- Install paket dasar (curl, wget, gnupg, jq, dll.)
- Set timezone
- Disable UFW (untuk lab)

### `docker`
- Hapus Docker versi lama
- Tambah Docker GPG key + repository
- Install Docker CE + Docker Compose plugin
- Enable Docker service
- Tambah user ke grup docker

### `jenkins`
- Buat direktori Jenkins home + JCasC
- Template JCasC configuration (admin, credentials, jobs, tools)
- Copy plugins.txt
- Jalankan Jenkins container dengan JCasC
- Install Docker CLI + Ansible di dalam container
- Install plugins via jenkins-plugin-cli
- Copy Ansible config ke jenkins_home (untuk deploy dari pipeline)

### `deploy`
- Buat direktori deployment
- Template docker-compose.yml
- Simpan image saat ini untuk rollback
- Login + pull image dari Docker Hub
- Deploy via Docker Compose
- Smoke test (health check)
- Rollback otomatis jika smoke test gagal
- Cleanup dangling Docker images

## ⚙️ Jenkins Configuration as Code (JCasC)

JCasC mengkonfigurasi Jenkins secara otomatis tanpa perlu setup manual via UI:

| Komponen | Konfigurasi |
|----------|-------------|
| **Admin User** | `kelompok3` / `miniproject5` |
| **CSRF Protection** | Enabled (crumbIssuer) |
| **Security** | No anonymous access, no signup |
| **Credentials** | DockerHub (username/password), Target SSH key |
| **Pipeline Job** | `miniproject-devops` — SCM polling setiap 5 menit |
| **Tools** | Git (default), NodeJS 20.11.1 |
| **Email** | SMTP via Gmail (port 587, TLS) |
| **Plugins** | 15 plugins (JCasC, Git, Pipeline, Docker, Blue Ocean, Ansible, dll.) |
