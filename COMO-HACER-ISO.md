# Como hacer el ISO de DogeOS para VirtualBox

La forma recomendada, sin instalar Linux ni herramientas en tu PC, es construir el ISO en GitHub Actions.

## 1. Subir el proyecto a GitHub

1. Entra a https://github.com/
2. Crea un repositorio nuevo.
3. Sube todos los archivos de esta carpeta `Doge O` al repositorio.
4. Asegurate de que exista este archivo en GitHub:

```text
.github/workflows/main.yml
```

## 2. Crear el ISO en GitHub

1. Abre tu repositorio en GitHub.
2. Entra a la pestana `Actions`.
3. Selecciona `Build DogeOS ISO`.
4. Presiona `Run workflow`.
5. Espera a que termine. Puede tardar bastante porque descarga Ubuntu y reconstruye el sistema.
6. Abre el resultado terminado y descarga el artifact:

```text
DogeOS-0.1-amd64
```

Adentro estaran:

```text
DogeOS-0.1-amd64.iso
DogeOS-0.1-amd64.sha256
```

El archivo que necesitas para VirtualBox es:

```text
DogeOS-0.1-amd64.iso
```

## 3. Crear la maquina virtual en VirtualBox

Usa estos ajustes:

```text
Nombre: DogeOS
Tipo: Linux
Version: Ubuntu (64-bit)
RAM: 6144 MB o mas
CPU: 2 nucleos o mas
Disco: 35 GB o mas
Video: 128 MB
3D Acceleration: Activado
Red: NAT
```

Luego:

1. Ve a `Settings` -> `Storage`.
2. Selecciona el icono del disco optico.
3. Elige `DogeOS-0.1-amd64.iso`.
4. Inicia la maquina virtual.

## 4. Roblox y EXE

Para Roblox, usa `Install Roblox (Sober)` dentro de DogeOS.

Para otros programas `.exe`, usa `Install EXE Support` y luego:

```bash
wine programa.exe
```

Importante: el `.exe` de Roblox para Windows no es una ruta confiable en Linux. DogeOS prepara Sober para Roblox y Wine/Bottles para otros `.exe`.
