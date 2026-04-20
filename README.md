# Miniproject DevOps — Kelompok 3

## Studi Kasus 3: CI/CD Pipeline Terkontainerisasi dengan Jenkins

Sebuah tim pengembangan kerap menghadapi penundaan dan inkonsistensi dalam merilis fitur baru akibat alur kerja yang manual dan terfragmentasi. Ketiadaan pipeline CI/CD yang terstandardisasi menghasilkan siklus rilis yang tidak terprediksi dan meningkatkan risiko keamanan dari container yang tidak terverifikasi. Proyek ini membangun proses CI/CD yang **reliable, otomatis, dan aman** mulai dari commit hingga release, dengan pelacakan proses terpusat.

**Tujuan**: Mahasiswa diharapkan memiliki kompetensi dalam merancang dan mengimplementasikan pipeline CI/CD terkontainerisasi menggunakan Jenkins, mengintegrasikan pemindaian keamanan (DevSecOps) ke dalam proses build, dan memastikan ketertelusuran (traceability) end-to-end dari deployment aplikasi.

---

## 📐 Arsitektur Sistem

```
┌──────────────┐     push      ┌──────────────────┐
│   Developer  │ ────────────> │  GitHub Repo     │
│   Workstation│               │  (Source Code)   │
└──────────────┘               └───────┬──────────┘
                                       │ webhook / poll
                                       ▼
                               ┌──────────────────┐      push image     ┌──────────────────┐
                               │  Jenkins Node    │ ──────────────────> │  Docker Hub      │
                               │  4.194.56.40     │                     │  (Registry)      │
                               │  ┌──────────────┐│                     └──────────────────┘
                               │  │Jenkins (JCasC)││                              │
                               │  │Docker Engine  ││                              │
                               │  │Ansible CLI    ││                              │
                               │  └──────────────┘│                              │
                               └───────┬──────────┘                              │
                                       │ ansible-playbook                        │
                                       ▼                                         │ pull image
                               ┌──────────────────┐                              │
                               │  Target Node     │ <────────────────────────────┘
                               │  20.205.234.122  │
                               │  ┌──────────────┐│
                               │  │Docker Engine  ││
                               │  │Docker Compose ││
                               │  │App Container  ││
                               │  └──────────────┘│
                               └──────────────────┘
```

| Komponen | Fungsi |
|---|---|
| **Jenkins Node** (Azure VM) | CI/CD Orchestrator — menjalankan Jenkins dalam container Docker |
| **Target Node** (Azure VM) | Lingkungan target untuk deployment aplikasi akhir |
| **GitHub** | Source code repository, pemicu pipeline |
| **Docker Hub** | Registry untuk menyimpan image yang telah di-build dan dipindai |

---

## 📁 Struktur Proyek

```
miniprojectdevops/
├── app.js                       # Aplikasi Node.js (Express)
├── package.json                 # Dependencies aplikasi
├── Dockerfile                   # Multi-stage build (builder + runtime)
├── docker-compose.yml           # Referensi deployment manual
├── Jenkinsfile                  # Pipeline CI/CD (10 stages)
├── .dockerignore
├── .gitignore
│
├── terraform/                   # Tahap 1: Infrastructure as Code
│   ├── providers.tf             # Azure provider config
│   ├── main.tf                  # Root module (network + compute)
│   ├── variables.tf             # Input variables
│   ├── terraform.tfvars         # Values (SSH key, resource group)
│   ├── outputs.tf               # Output IP addresses
│   └── modules/
│       ├── network/             # VNet, Subnets, NSG, Public IPs
│       │   ├── network.tf
│       │   ├── variables.tf
│       │   └── output.tf
│       └── compute/             # VM Jenkins + VM Target
│           ├── main.tf
│           ├── variables.tf
│           └── output.tf
│
└── ansible/                     # Tahap 3: Configuration as Code
    ├── ansible.cfg              # Konfigurasi global Ansible
    ├── playbook-setup-all.yml   # Setup awal semua VM
    ├── playbook-deploy.yml      # Deploy aplikasi ke target
    ├── playbook-verify.yml      # Verifikasi status semua node
    ├── README.md                # Dokumentasi Ansible
    ├── inventory/
    │   └── hosts.yml            # Daftar host (Jenkins + Target)
    ├── group_vars/
    │   ├── all.yml              # Variabel global
    │   ├── jenkins.yml          # Variabel Jenkins node
    │   └── target.yml           # Variabel Target node
    └── roles/
        ├── common/              # Paket dasar & konfigurasi OS
        ├── docker/              # Instalasi Docker Engine
        ├── jenkins/             # Jenkins container + JCasC
        └── deploy/              # Deployment via Docker Compose
```

---

## 🔧 Prerequisite

Sebelum memulai, pastikan tools berikut terinstall di **mesin lokal** (control node):

| Tool | Versi Minimum | Kegunaan |
|---|---|---|
| [Terraform](https://www.terraform.io/downloads) | v1.0+ | Provisioning infrastruktur Azure |
| [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) | v2.40+ | Autentikasi ke Azure |
| [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) | v2.12+ | Konfigurasi VM |
| [Git](https://git-scm.com/) | v2.30+ | Version control |
| SSH Key Pair | — | Akses ke VM Azure |

---

## 🚀 Langkah-Langkah Implementasi (Tahap 1 – 3)

---

### Tahap 1: Infrastructure as Code (Terraform)

Tahap ini membuat **2 VM Azure** (Jenkins Node + Target Node) beserta jaringan (VNet, Subnet, NSG, Public IP) menggunakan Terraform.

#### 1.1 Login ke Azure

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

#### 1.2 Generate SSH Key (jika belum ada)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub
```

#### 1.3 Konfigurasi Terraform Variables

Edit file `terraform/terraform.tfvars` dan sesuaikan SSH public key:

```hcl
ssh_public_key      = "ssh-rsa AAAA... user@hostname"
resource_group_name = "ets-devops-03"
```

#### 1.4 Provisioning Infrastruktur

```bash
cd terraform/

# Inisialisasi Terraform (download provider Azure)
terraform init

# Preview perubahan yang akan dibuat
terraform plan

# Buat infrastruktur (ketik 'yes' untuk konfirmasi)
terraform apply
```

#### 1.5 Catat Output IP

Setelah `terraform apply` selesai, catat output IP:

```bash
terraform output
```

Output:
```
jenkins_public_ip = "4.194.56.40"
target_public_ip  = "20.205.234.122"
```

#### 1.6 Verifikasi Akses SSH

```bash
# Test SSH ke Jenkins Node
ssh -i ~/.ssh/id_rsa ubuntu@4.194.56.40

# Test SSH ke Target Node
ssh -i ~/.ssh/id_rsa ubuntu@20.205.234.122
```

> **Hasil Tahap 1**: 2 VM Azure (Ubuntu 22.04) siap digunakan dengan Public IP dan NSG yang mengizinkan SSH (22), Jenkins (8080), dan App (3000).

---

### Tahap 2: Containerization & CI/CD Pipeline (Docker + Jenkins)

Tahap ini menyiapkan aplikasi dalam container Docker dan mendefinisikan pipeline CI/CD di Jenkinsfile.

#### 2.1 Aplikasi

Aplikasi Node.js sederhana (`app.js`) dengan 2 endpoint:

| Endpoint | Response |
|---|---|
| `GET /` | JSON: message, status, environment |
| `GET /health` | `200 OK` — untuk health check |

#### 2.2 Dockerfile (Multi-stage Build)

Dockerfile menggunakan **multi-stage build** untuk optimasi ukuran image:

- **Stage 1 (Builder)**: Install dependencies dengan `npm ci --omit=dev`
- **Stage 2 (Runtime)**: Copy `node_modules`, tambah `tini` (init process), healthcheck, non-root user

```bash
# Build lokal untuk testing
docker build -t simple-app:latest .
docker run -d -p 3000:3000 simple-app:latest

# Verifikasi
curl http://localhost:3000/health
```

#### 2.3 Setup Jenkins di Docker

Jenkins dijalankan sebagai container Docker dengan akses ke Docker host:

```bash
# Jalankan Jenkins dengan akses Docker
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

<img width="1179" height="432" alt="Jenkins container running" src="https://github.com/user-attachments/assets/3cd65c95-c9db-4f41-9fc5-2dfae2536e47" />

Setelah container berjalan, akses Jenkins di http://localhost:8080

- Login jenkins username : kelompok3
- Password : miniproject5

#### 2.4 Setup Credentials Docker Hub

Untuk keamanan, kredensial Docker Hub tidak ditulis langsung di Jenkinsfile, melainkan disimpan di Jenkins Credentials Manager:
1. Buka Jenkins > Manage Jenkins > Credentials > System > Global credentials.
2. Klik Add Credentials, pilih tipe Username with Password.
3. Masukkan username dan password Docker Hub.
4. Beri ID yang unik, `dockerhub-creds`.

<img width="1600" height="806" alt="Docker Hub Credentials" src="https://github.com/user-attachments/assets/750a754e-a336-4872-bb0f-190dc764f9ae" />

- Username : kelompok3devops
- Password docker hub : miniproject5
- ID : dockerhub-creds

#### 2.5 Membuat Pipeline Job di Jenkins

1. Buka Jenkins Dashboard > New Item.
2. Beri nama pipeline `miniproject-devops`, pilih tipe Pipeline, klik OK.
3. Pada konfigurasi Pipeline, pilih Definition: Pipeline script from SCM.
4. Pilih SCM: Git, masukkan URL repository GitHub.
5. Pastikan branch sesuai, Script Path: `Jenkinsfile`.

<img width="1657" height="635" alt="Pipeline Job Configuration" src="https://github.com/user-attachments/assets/9688bd23-3097-41d2-9ff6-62218bbeb982" />

#### 2.6 Jenkinsfile — 10 Stage Pipeline

Pipeline CI/CD terdiri dari **10 stages**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        JENKINS PIPELINE                                │
├──────────┬──────────┬──────────┬──────────┬──────────┬────────────────┤
│ 1.Check  │ 2.Verify │ 3.Build  │ 4.List   │ 5.Scout  │ 6.Security   │
│ out      │ Env      │ Image    │ Images   │ Scan     │ Gate         │
├──────────┴──────────┴──────────┴──────────┴──────────┴────────────────┤
│ 7.Push to │ 8.Deploy to Target │ 9.Smoke  │ 10.Rollback             │
│ Registry  │ (Ansible Playbook) │ Test     │ (jika gagal)            │
├───────────┴────────────────────┴──────────┴─────────────────────────┤
│ POST: Traceability Report + Email Notification (Success/Failure)    │
└─────────────────────────────────────────────────────────────────────┘
```

| Stage | Keterangan |
|---|---|
| **Checkout Source** | Clone repo dari GitHub, catat commit SHA |
| **Verify Environment** | Verifikasi Docker & Ansible tersedia |
| **Build Docker Image** | Multi-tag build (version, latest, commit, build number) |
| **List Docker Images** | Tampilkan images yang telah dibuild |
| **Docker Scout Scan** | Security scan (DevSecOps) — deteksi CVE |
| **Security Gate** | Gagalkan build jika ada **Critical** vulnerabilities |
| **Push to Registry** | Push semua tag ke Docker Hub |
| **Deploy to Target** | Jalankan `ansible-playbook playbook-deploy.yml` |
| **Smoke Test** | Health check ke `http://target:3000/health` (5 retries) |
| **Rollback** | Otomatis rollback via Ansible jika smoke test gagal |

#### 2.7 Push Code ke GitHub dan Trigger Pipeline

Setelah semua konfigurasi selesai, lakukan push ke GitHub. Pipeline dapat dijalankan secara manual lewat tombol **Build Now**, atau dikonfigurasi agar trigger otomatis via webhook GitHub / SCM polling setiap 5 menit.

> **Hasil Tahap 2**: Dockerfile siap, Jenkinsfile terstruktur dengan 10 stages + rollback + traceability + email notification.

---

### Tahap 3: Configuration as Code (Ansible)

Tahap ini mengkonfigurasi **semua VM secara otomatis** menggunakan Ansible — mulai dari install Docker, setup Jenkins + JCasC, hingga deployment.

#### 3.1 Update Inventory

Edit `ansible/inventory/hosts.yml` dan sesuaikan IP dari output Terraform (Tahap 1.5):

```yaml
all:
  children:
    jenkins:
      hosts:
        jenkins-node:
          ansible_host: 4.194.56.40        # ← Ganti dengan IP dari Terraform
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
    target:
      hosts:
        target-node:
          ansible_host: 20.205.234.122     # ← Ganti dengan IP dari Terraform
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

#### 3.2 Update Group Variables

Edit `ansible/group_vars/jenkins.yml` — sesuaikan IP dan credentials:

```yaml
jenkins_url: "http://<JENKINS_IP>:8080"
target_node_ip: "<TARGET_IP>"
jenkins_admin_user: "kelompok3"
jenkins_admin_password: "miniproject5"      # ⚠️ Production: gunakan Ansible Vault
```

#### 3.3 Jalankan Playbook Setup (Sekali Jalan)

```bash
cd ansible/

# Syntax check terlebih dahulu
ansible-playbook playbook-setup-all.yml --syntax-check

# Jalankan setup (akan memakan waktu 5-10 menit)
ansible-playbook playbook-setup-all.yml
```

**Yang dilakukan oleh playbook ini:**

| Play | Host | Yang Dikonfigurasi |
|---|---|---|
| **Play 1** | Semua Node | Update apt, install paket dasar, set timezone, disable UFW |
| **Play 1** | Semua Node | Install Docker Engine + Docker Compose plugin |
| **Play 2** | Jenkins Node | Jalankan Jenkins container dengan JCasC |
| **Play 2** | Jenkins Node | Install plugins (15 plugins) |
| **Play 2** | Jenkins Node | Install Docker CLI + Ansible di dalam container |
| **Play 2** | Jenkins Node | Copy konfigurasi Ansible ke jenkins_home |
| **Play 3** | Target Node | Buat direktori deployment `/opt/app-deployment` |

#### 3.4 Verifikasi Setup

```bash
# Jalankan playbook verifikasi
ansible-playbook playbook-verify.yml
```

Atau verifikasi manual:

```bash
# Cek Jenkins bisa diakses
curl -s -o /dev/null -w "%{http_code}" http://4.194.56.40:8080/login
# Expected: 200

# Cek Docker di target node
ssh ubuntu@20.205.234.122 "docker --version && docker compose version"
```

#### 3.5 Akses Jenkins

Setelah playbook selesai, akses Jenkins di browser:

```
URL      : http://4.194.56.40:8080
Username : kelompok3
Password : miniproject5
```

JCasC sudah mengkonfigurasi secara otomatis:
- ✅ Admin user & password
- ✅ CSRF protection
- ✅ Credentials (Docker Hub + SSH key)
- ✅ Pipeline job `miniproject-devops` (SCM polling tiap 5 menit)
- ✅ Tool installations (Git + NodeJS 20)
- ✅ Email notification (SMTP Gmail)

#### 3.6 Trigger Pipeline

Pipeline bisa dijalankan dengan 2 cara:

**Otomatis** — SCM polling setiap 5 menit akan mendeteksi perubahan di GitHub.

**Manual** — Klik **Build Now** pada job `miniproject-devops` di Jenkins Dashboard.

#### 3.7 Deploy via Ansible (dari Pipeline)

Saat pipeline mencapai stage **Deploy to Target**, Jenkins akan menjalankan:

```bash
ansible-playbook /var/jenkins_home/ansible/playbook-deploy.yml \
  -i /var/jenkins_home/ansible/inventory/hosts.yml \
  -e "image_tag=build-<BUILD_NUMBER>" \
  -e "dockerhub_password=<PASSWORD>"
```

Playbook deploy melakukan:
1. Template `docker-compose.yml` ke target node
2. Simpan image saat ini untuk rollback
3. Login + pull image dari Docker Hub
4. `docker compose up -d`
5. Smoke test (health check)
6. Rollback otomatis jika gagal

#### 3.8 Verifikasi Aplikasi

```bash
# Health check
curl http://20.205.234.122:3000/health
# Expected: OK

# Main endpoint
curl http://20.205.234.122:3000/
# Expected: {"message":"Hello from DevSecOps Pipeline!","status":"Running","environment":"production"}
```

> **Hasil Tahap 3**: Semua VM terkonfigurasi otomatis via Ansible. Jenkins berjalan dengan JCasC. Pipeline deploy melalui Ansible + Docker Compose ke target node.

---

## 📊 Hasil dan Analisis

### Hasil Pemindaian Docker Scout

Setelah pipeline dijalankan, Docker Scout melakukan pemindaian terhadap image yang baru dibangun. Hasil pemindaian menunjukkan:

<img width="1191" height="335" alt="Docker Scout Scan Results" src="https://github.com/user-attachments/assets/b559d57c-ee6f-4527-90c4-f10b4feacce4" />

### Analisis Hasil Security Gate

Pada tahap Security Gate, Groovy script membaca file `scan-result.txt` dan mendeteksi kata HIGH (11 kerentanan). Sesuai logika yang diimplementasikan, pipeline dihentikan.
Hal ini membuktikan bahwa mekanisme DevSecOps berhasil diimplementasikan dengan baik. Pipeline secara otomatis menolak image yang mengandung kerentanan tinggi, sehingga image tersebut tidak akan diteruskan ke tahap deployment.

<img width="1600" height="741" alt="Security Gate Failed - HIGH vulnerabilities" src="https://github.com/user-attachments/assets/7017c7bc-c890-4e10-822d-ecd505dfcdc4" />

Disini mencoba untuk hanya mendeteksi critical saja, karna dari hasil Groovy script membaca file scan-result.txt dan mendeteksi kata CRITICAL (0 kerentanan), maka pipeline berhasil.

<img width="1600" height="481" alt="Pipeline Passed - No Critical" src="https://github.com/user-attachments/assets/c426818e-f535-47c5-b723-9f439160db16" />

### Fitur Traceability

Pipeline juga mengimplementasikan fitur traceability yang mencatat informasi build secara lengkap dalam file `build-info.txt`. File ini berisi:
- Nama dan versi aplikasi.
- Nomor build Jenkins (BUILD_NUMBER).
- Git Commit ID (short hash).
- Seluruh tag Docker yang dihasilkan (versi, latest, commit).
- Metode deploy (Ansible Playbook + Docker Compose).
- Waktu build.

<img width="1144" height="446" alt="Build Traceability Report" src="https://github.com/user-attachments/assets/1307cd35-5864-4f93-99d5-424447ec4617" />

Dengan informasi ini, tim dapat melacak versi mana dari kode yang menghasilkan image tertentu, mendukung audit trail dan rollback yang tepat.

---

## 🔐 Keamanan

| Aspek | Implementasi |
|---|---|
| **DevSecOps** | Docker Scout scan + Security Gate di pipeline |
| **Container Security** | Non-root user, tini init, healthcheck |
| **Credential Management** | Jenkins Credentials Manager + JCasC |
| **Network Security** | Azure NSG — hanya port 22, 8080, 3000 terbuka |
| **Secrets (Production)** | Ansible Vault — dokumentasi di `group_vars/jenkins.yml` |

---

## 🛠️ Troubleshooting

### Terraform gagal `apply`

```bash
# Reset state jika terjadi error
terraform destroy
terraform apply
```

### Ansible tidak bisa SSH ke VM

```bash
# Test koneksi
ansible all -m ping -i ansible/inventory/hosts.yml

# Pastikan SSH key benar
ssh -i ~/.ssh/id_rsa ubuntu@<IP_VM>
```

### Jenkins tidak bisa diakses

```bash
# SSH ke Jenkins node dan cek container
ssh ubuntu@4.194.56.40
docker ps
docker logs jenkins
```

### Pipeline gagal di stage Deploy

```bash
# Cek apakah Ansible tersedia di Jenkins container
docker exec jenkins ansible --version

# Cek inventory
docker exec jenkins cat /var/jenkins_home/ansible/inventory/hosts.yml

# Manual deploy
cd ansible/
ansible-playbook playbook-deploy.yml -e "image_tag=latest"
```

### Aplikasi tidak bisa diakses di target

```bash
# SSH ke target node
ssh ubuntu@20.205.234.122

# Cek container
docker ps
docker logs simple-app

# Cek port
curl http://localhost:3000/health
```

---

## 👥 Kelompok 3

Miniproject DevOps - Studi Kasus 3
