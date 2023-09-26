#!/bin/bash

#########################
# Instalación de Docker #
#########################

# Configurar el repositorio

sudo apt update

# Instalar Docker

sudo apt install docker.io docker-compose -y

############################
# Instalación de Portainer #
############################

# Crear volumen para la base de datos de Portainer

sudo docker volume create portainer_data

# Descargar e instalar Portainer

sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
