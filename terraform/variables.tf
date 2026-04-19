variable "resource_group_name" {
  default = "ets-devops-03"
}

variable "location" {
  default = "Southeast Asia"
}

variable "ssh_public_key" {
  type        = string
  description = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCyeLgNa1KGeTfa1Tzcpyt01ImSO473RSb/kkaWzBZhnp0GzqMz06vZ69htxuMHn1kCxlomjkdpMAZM5o3FZM79zHnp/6CD6TExNwC5VA81b1biNTWwUjCNZn6wdi+ZP142UbbM7eGpnwLfwl2DCd9ZLmjAAYml1/turdNgB2kq+nACWcXcsyVuSuLHZiJkdf2OXe2h+AeAyBYdIfd8n+b9sENV9S2ySV9xQAzwB7dE8Sjy7ZcN2pDN6UfD7ySjWBajKWPyjsTBYH64Lw/giQzvIzqaioJeRhMBQ8Yh5MM6ltwUP8+TvYfF4vzcuoay8OrhC+PDUIUQqXM2v40a2qVnOMZsUEs9myawhQjvK2CB964O7Qg3+sfTV4ptIYemwCroey7MuSd0sHSmakK+/7U8LF61KADwr/eoHuA06DSDEVPOYPqy4zwXh+0lV9VXOT8Enwfgy220+LSXrRfOjTwSBvcWT4GryLeOEVqP8waW1rg67Rn51/LgW0zSih+v1WhlAJqsSpi6oXEFNDnUE6xkHjWrwFhwNletnoH2xENN7EWHhqJJUyW0e8UMC1nXJvAEzr8ScAPW57z/Xeus11RfcXSquLysF3R6se+afxAC3YupHGdZlN2qIGwrEERha2IAxsv+hAKML5vI+bLI7g4k7+nCfRSxsJs2ULP2+u8G9Q== haidar rafi@LAPTOP-083HK15R"
}

variable "admin_username" {
  default = "ubuntu"
}