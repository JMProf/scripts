#!/bin/bash

#########################
# Instalación de Docker #
#########################

echo "Instalando Docker Engine"

# Configurar el repositorio. Extraido de https://docs.docker.com/engine/install/ubuntu/

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Instalar Docker

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Añadiendo el usuario actual al grupo de Docker..."
sudo usermod -aG docker $USER

echo "Docker instalado. Esperando 5 segundos para que el servicio se inicie..."
sleep 5

############################
# Instalación de Portainer #
############################

# Crear volumen para la base de datos de Portainer

echo "Instalando Portainer CE"

sudo docker volume create portainer_data

# Descargar e instalar Portainer

sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

echo "Instalación de Docker y Portainer completada."
echo "IMPORTANTE: Cierra la sesión y vuelve a iniciarla para usar 'docker' sin 'sudo'."

