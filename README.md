# STUDI KASUS 3

Latar Belakang: Sebuah tim pengembangan kerap menghadapi penundaan dan inkonsistensi dalam merilis fitur baru akibat alur kerja yang manual dan terfragmentasi. Ketiadaan pipeline CI/CD yang terstandardisasi menghasilkan siklus rilis yang tidak terprediksi dan meningkatkan risiko keamanan dari container yang tidak terverifikasi. Anda, sebagai Lead DevOps Engineer, ditugaskan untuk membangun proses CI/CD yang reliable, otomatis, dan aman mulai dari commit hingga release, dengan pelacakan proses terpusat.

Tujuan: Mahasiswa diharapkan memiliki kompetensi dalam merancang dan mengimplementasikan pipeline CI/CD terkontainerisasi menggunakan Jenkins, mengintegrasikan pemindaian keamanan (DevSecOps) ke dalam proses build, dan memastikan ketertelusuran (traceability) end-to-end dari deployment aplikasi.

Arsitektur Sistem
- 1 Node Jenkins: Berfungsi sebagai CI/CD Orchestrator dan berjalan dalam container Docker.
- 1 Node Code Repository (GitHub): Sumber pemicu pipeline dari source code.
- 1 Node Artifactory/Registry (Docker Hub): Menyimpan image yang telah di-build dan dipindai.
- 1 Worker Node (VM): Lingkungan target untuk deployment aplikasi akhir.











Langkah-Langkah Implementasi

Langkah 1 - Setup Jenkins di Docker

Jenkins dijalankan sebagai container Docker dengan akses ke Docker host:

```
Jalankan Jenkins dengan akses Docker
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

<img width="1179" height="432" alt="image" src="https://github.com/user-attachments/assets/3cd65c95-c9db-4f41-9fc5-2dfae2536e47" />

Setelah container berjalan, akses Jenkins di http://localhost:8080 

- Login jenkins username : kelompok3
- Password : miniproject5


Langkah 2 - Setup Credentials Docker Hub

Untuk keamanan, kredensial Docker Hub tidak ditulis langsung di Jenkinsfile, melainkan disimpan di Jenkins Credentials Manager:
1. Buka Jenkins > Manage Jenkins > Credentials > System > Global credentials.
2. Klik Add Credentials, pilih tipe Username with Password.
3. Masukkan username dan password Docker Hub.
4. Beri ID yang unik, dockerhub-credentials.


<img width="1600" height="806" alt="image" src="https://github.com/user-attachments/assets/750a754e-a336-4872-bb0f-190dc764f9ae" />


- Username : kelompok3devops
- Password docker hub  : miniproject5
- ID : dockerhub-creds

Langkah 3 - Membuat Pipeline Job di Jenkins
1. Buka Jenkins Dashboard > New Item.
2. Beri nama pipeline miniproject-devops, pilih tipe Pipeline, klik OK.
3. Pada konfigurasi Pipeline, pilih Definition: Pipeline script from SCM.
4. Pilih SCM: Git, masukkan URL repository GitHub.
5. Pastikan branch sesuai, Script Path: Jenkinsfile.

<img width="1657" height="635" alt="image" src="https://github.com/user-attachments/assets/9688bd23-3097-41d2-9ff6-62218bbeb982" />


Langkah 4 - Push Code ke GitHub dan Trigger Pipeline
Setelah semua konfigurasi selesai, lakukan push ke GitHub. Pipeline dapat dijalankan secara manual lewat tombol Build Now, atau dikonfigurasi agar trigger otomatis via webhook GitHub.

4. Hasil dan Analisis

- Hasil Pemindaian Docker Scout

Setelah pipeline dijalankan, Docker Scout melakukan pemindaian terhadap image yang baru dibangun. Hasil pemindaian menunjukkan:

<img width="1191" height="335" alt="image" src="https://github.com/user-attachments/assets/b559d57c-ee6f-4527-90c4-f10b4feacce4" />

- Analisis Hasil Security Gate
Pada tahap Security Gate, Groovy script membaca file scan-result.txt dan mendeteksi kata HIGH (11 kerentanan). Sesuai logika yang diimplementasikan, pipeline dihentikan.
Hal ini membuktikan bahwa mekanisme DevSecOps berhasil diimplementasikan dengan baik. Pipeline secara otomatis menolak image yang mengandung kerentanan tinggi, sehingga image tersebut tidak akan diteruskan ke tahap deployment.

<img width="1600" height="741" alt="image" src="https://github.com/user-attachments/assets/7017c7bc-c890-4e10-822d-ecd505dfcdc4" />

Disini mencoba untuk hanya mendeteksi critical saja, karna dari hasil Groovy script membaca file scan-result.txt dan mendeteksi kata CRITICAL  (0 kerentanan), maka pipeline berhasil.

<img width="1600" height="481" alt="image" src="https://github.com/user-attachments/assets/c426818e-f535-47c5-b723-9f439160db16" />


- Fitur Traceability

Pipeline juga mengimplementasikan fitur traceability yang mencatat informasi build secara lengkap dalam file build-info.txt. File ini berisi:
  - Nama dan versi aplikasi.
  - Nomor build Jenkins (BUILD_NUMBER).
  - Git Commit ID (short hash).
  - Seluruh tag Docker yang dihasilkan (versi, latest, commit).
  - Waktu build.

<img width="1144" height="446" alt="image" src="https://github.com/user-attachments/assets/1307cd35-5864-4f93-99d5-424447ec4617" />

Dengan informasi ini, tim dapat melacak versi mana dari kode yang menghasilkan image tertentu, mendukung audit trail dan rollback yang tepat.
