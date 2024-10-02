#!/bin/bash

# Comprobamos si se han pasado dos argumentos (dos carpetas)
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 carpeta1 carpeta2"
    exit 1
fi

# Carpetas de entrada
carpeta1=$1
carpeta2=$2

# Comprobamos si las carpetas existen
if [ ! -d "$carpeta1" ]; then
    echo "Error: La carpeta '$carpeta1' no existe."
    exit 1
fi

if [ ! -d "$carpeta2" ]; then
    echo "Error: La carpeta '$carpeta2' no existe."
    exit 1
fi

# Recorremos todos los ficheros de la carpeta1
for fichero1 in "$carpeta1"/*; do
    # Obtenemos el nombre base del archivo
    nombre_fichero=$(basename "$fichero1")

    # Buscamos el fichero correspondiente en carpeta2 con " (copia)" añadido
    fichero_copia="$carpeta2/${nombre_fichero%.*} (copia).${nombre_fichero##*.}"

    # Verificamos si existe el archivo copia en carpeta2
    if [ -f "$fichero_copia" ]; then
        echo "Comparando '$nombre_fichero' con su copia..."

        # Llamamos al script de comparación
        ./comparar_ficheros.sh "$fichero1" "$fichero_copia"
    else
        echo "No se encontró la copia de '$nombre_fichero' en '$carpeta2'."
    fi
done

