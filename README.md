Miniproject DevOps — Kelompok 3

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

#### Provisioning Infrastruktur

cd terraform

# Inisialisasi Terraform (download provider Azure)
<img width="948" height="523" alt="image" src="https://github.com/user-attachments/assets/a9a8e940-6aa7-4ece-b55e-662727e3eb40" />
```
terraform init
```

# Preview perubahan yang akan dibuat
<img width="1118" height="973" alt="image" src="https://github.com/user-attachments/assets/a4091a2c-23df-4846-a2b3-333f8603c38a" />
```
terraform plan
```

# Buat infrastruktur (ketik 'yes' untuk konfirmasi)
<img width="1012" height="807" alt="image" src="https://github.com/user-attachments/assets/4da7a6ed-ccce-402f-a5ab-ce3497f7c8f8" />
```
terraform apply
```

#### 1.5 Catat Output IP
<img width="781" height="239" alt="image" src="https://github.com/user-attachments/assets/4b54a40d-0a95-44c2-b111-1ef3339f0b34" />
Setelah `terraform apply` selesai, catat output IP menggunakan
```bash
terraform output
```
Output ini akan digunakan oleh ansible dalam template inventory/hosts.yml dan group_vars/target.yml sebagai variable IP yang dibuat secara otomatis setelah terraform apply.

#### Tahap 2: Containerization & CI/CD Pipeline (Docker + Jenkins)
Tahap ini berfokus pada pengemasan aplikasi ke dalam Docker dan penyusunan alur kerja otomatis di Jenkins.

### 2.1 Multi-stage Docker Build
Aplikasi dibangun menggunakan file Dockerfile dengan strategi Multi-stage build untuk meminimalkan ukuran image dan meningkatkan keamanan:
- Stage Build: Menggunakan node:20-alpine untuk menginstall dependensi.
- Stage Runtime: Hanya mengambil file yang diperlukan, menggunakan tini sebagai init process, dan menjalankan aplikasi dengan user non-root (node).

### 2.2 Jenkins Configuration as Code (JCasC)
Alih-alih konfigurasi manual, Jenkins dikonfigurasi menggunakan file ansible/roles/jenkins/templates/jenkins-casc.yml.j2. Untuk otomatisasi user admin, password, plugin, kredensial Docker Hub, hingga Job Pipeline dibuat secara otomatis saat Ansible dijalankan.

### 2.3 Struktur Jenkinsfile (The Pipeline)
Pipeline didefinisikan dalam Jenkinsfile dengan alur sebagai berikut:
1. Initial Setup: Mengambil commit ID pendek untuk tagging.
2. Build: Membuat image Docker dengan 3 tag sekaligus (latest, build-number, commit-sha).
3. Security Scan (DevSecOps): Menggunakan Docker Scout untuk memindai kerentanan (CVE). Pipeline akan FAIL jika ditemukan kerentanan level CRITICAL.
4. Push: Mengunggah image yang aman ke Docker Hub.
5. Deploy via Ansible: Jenkins memicu playbook-deploy.yml untuk memperbarui aplikasi di Target Node.
6. Smoke Test: Melakukan pengujian HTTP ke endpoint /health milik Target Node.
7. Rollback: Jika Smoke Test gagal, Jenkins memicu deployment ulang ke versi (build number) sebelumnya.

### Tahap 3: Configuration as Code (Ansible)
Ansible berperan sebagai "perekat" yang mengonfigurasi VM yang telah dibuat oleh Terraform.

### 3.1 Integrasi Terraform & Ansible
Proyek ini menggunakan fitur local_file pada Terraform untuk menulis file secara otomatis:
- ansible/inventory/hosts.yml: Berisi IP dinamis dari Azure.
- ansible/group_vars/target.yml: Berisi variabel IP Target Node.
Hal ini memastikan tidak ada IP yang perlu di-input manual.

### 3.2 Menjalankan Setup Infrastruktur
Jalankan perintah ini di mesin lokal untuk mengonfigurasi kedua VM:
```
cd ansible
```
lalu
```
ansible-playbook playbook-setup-all.yml
```
<img width="1149" height="940" alt="image" src="https://github.com/user-attachments/assets/e8361fba-e6fb-469c-bb2a-f0d53aec039c" />


### 3.3 Mekanisme Deployment & Rollback (Ansible Role)
Role deploy pada Ansible dirancang dengan prinsip High Availability:
- Backup: Sebelum update, Ansible mencatat image yang sedang berjalan ke file .previous_image.
- Atomic: Menggunakan Docker Compose untuk memastikan transisi container yang lancar.
- Auto-Rollback: Jika uri module mendeteksi status code selain 200 pada healthcheck, Ansible akan mengeksekusi blok rescue untuk mengembalikan ke image versi sebelumnya secara instan.


## Hasil dan Analisis (Bukti Implementasi)
1. Verifikasi Infrastruktur
Setelah Ansible selesai, verifikasi status semua node:
```
ansible-playbook playbook-verify.yml
```
Hasil: Docker dan Jenkins harus berstatus "Running" di masing-masing node.

2. Keamanan (DevSecOps)
Berdasarkan implementasi pada Jenkinsfile, pipeline melakukan pengawasan ketat:
Jika Docker Scout menemukan CRITICAL vulnerability, pipeline akan berhenti (Aborted).
Hal ini mencegah pengiriman kode rentan ke lingkungan produksi.

4. Ketertelusuran (Traceability)
Setiap build menghasilkan artifact dan log yang jelas:
- Image Tagging memudahkan audit jika terjadi error pada versi tertentu.
- Endpoint /health pada app.js memberikan transparansi status aplikasi secara real-time.
- Ansible Vault: Disarankan untuk mengenkripsi vault_dockerhub_password pada group_vars/all/main.yml di lingkungan produksi.
