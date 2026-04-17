# STUDI KASUS 3

Latar Belakang: Sebuah tim pengembangan kerap menghadapi penundaan dan inkonsistensi dalam merilis fitur baru akibat alur kerja yang manual dan terfragmentasi. Ketiadaan pipeline CI/CD yang terstandardisasi menghasilkan siklus rilis yang tidak terprediksi dan meningkatkan risiko keamanan dari container yang tidak terverifikasi. Anda, sebagai Lead DevOps Engineer, ditugaskan untuk membangun proses CI/CD yang reliable, otomatis, dan aman mulai dari commit hingga release, dengan pelacakan proses terpusat.

Tujuan: Mahasiswa diharapkan memiliki kompetensi dalam merancang dan mengimplementasikan pipeline CI/CD terkontainerisasi menggunakan Jenkins, mengintegrasikan pemindaian keamanan (DevSecOps) ke dalam proses build, dan memastikan ketertelusuran (traceability) end-to-end dari deployment aplikasi.

Arsitektur Sistem
- 1 Node Jenkins: Berfungsi sebagai CI/CD Orchestrator dan berjalan dalam container Docker.
- 1 Node Code Repository (GitHub): Sumber pemicu pipeline dari source code.
- 1 Node Artifactory/Registry (Docker Hub): Menyimpan image yang telah di-build dan dipindai.
- 1 Worker Node (VM): Lingkungan target untuk deployment aplikasi akhir.

### Tahap 1: Kontainerisasi (Docker)

1. Buat Dockerfile untuk aplikasi sederhana.
1.1 Deskripsi Aplikasi

Aplikasi yang digunakan adalah aplikasi sederhana berbasis Node.js dengan framework Express. Aplikasi ini dibuat sebagai contoh service yang nantinya akan dibangun menjadi Docker image.

Aplikasi memiliki dua endpoint utama:
  - / untuk menampilkan pesan utama aplikasi
  - /health untuk melakukan pengecekan status aplikasi


1.2 Kode Aplikasi

Pipeline (Jenkins) harus menjalankan build aplikasi dan membuat image Docker.
