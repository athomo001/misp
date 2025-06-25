# Guía de Instalación de MISP (Malware Information Sharing Platform)

Este script automatiza la instalación de MISP 2.5 en Ubuntu 24.04 LTS. Fue traducido y mejorado  auspiciado por  cybeersecurity.

## Requisitos Previos

- Sistema Ubuntu 24.04 LTS
- Privilegios de administrador (root)
- Acceso a internet para descargar paquetes

## Privilegios Requeridos

**IMPORTANTE:** El script debe ejecutarse con privilegios de administrador. Use uno de los siguientes métodos:

```bash
# Opción 1: Usando sudo
sudo bash mispc.sh

# Opción 2: Desde una sesión root
sudo su
bash mispc.sh
```

## Configuraciones Obligatorias

Antes de ejecutar el script, debe modificar las siguientes variables en el archivo `mispc.sh`:

### 1. Dominio MISP (OBLIGATORIO)

```bash
MISP_DOMAIN='192.168.88.139'  # Cambie esto a su dominio o IP
```

> ⚠️ **ADVERTENCIA:** Si deja el valor predeterminado `misp.local`, el script se detendrá. Debe configurarlo con su propio dominio o dirección IP.

### 2. Correo de Administrador (RECOMENDADO)

```bash
GPG_EMAIL_ADDRESS="admin@admin.test"  # Cambie esto a su correo
```

> 📧 Este correo se usará para las credenciales de inicio de sesión y para la generación de claves GPG.

## Configuración de Certificado SSL

Si no proporciona un certificado SSL, el script generará uno automáticamente usando OpenSSL con estos parámetros:

```bash
OPENSSL_C='LU'                        # País (Country)
OPENSSL_ST='Luxembourg'               # Estado/Provincia (State)
OPENSSL_L='Luxembourg'                # Localidad/Ciudad (Locality)
OPENSSL_O='MISP'                      # Organización (Organization)
OPENSSL_OU='MISP'                     # Unidad Organizativa (Organizational Unit)
OPENSSL_CN=${MISP_DOMAIN}             # Nombre Común (Common Name) - Usa el valor de MISP_DOMAIN
OPENSSL_EMAILADDRESS='misp@'${MISP_DOMAIN}  # Correo electrónico
```

Para usar un certificado personalizado, configure la siguiente variable:

```bash
PATH_TO_SSL_CERT='/ruta/a/su/certificado.pem'  # Ruta a su certificado SSL
```

## Instalación

1. Descargue el script:
   ```bash
   wget https://github.com/user/mispc/raw/main/mispc.sh
   ```

2. Otorgue permisos de ejecución:
   ```bash
   chmod +x mispc.sh
   ```

3. Edite el script para configurar las variables necesarias:
   ```bash
   nano mispc.sh
   ```

4. Ejecute el script con privilegios de administrador:
   ```bash
   sudo bash mispc.sh
   ```

## Después de la Instalación

Después de completar la instalación, podrá acceder a su instancia MISP en:
```
https://su-dominio-o-ip
```

Las credenciales de administrador se mostrarán al final de la instalación y también se guardarán en:
```
/var/log/misp_settings.txt
```

## Solución de Problemas

Si encuentra problemas durante la instalación:

1. Verifique el registro de instalación:
   ```bash
   cat /var/log/misp_install.log
   ```

2. Asegúrese de que ha modificado el dominio MISP y el correo del administrador.

3. Verifique que está ejecutando el script con privilegios de administrador.

4. Revise los requisitos de memoria y espacio en disco.

## Personalización Adicional

El script está configurado para funcionar en un entorno estándar. Si necesita personalizar la instalación, considere modificar:

- Configuración de base de datos: usuario, contraseña, host y puerto.
- Ajustes de PHP: tamaño de memoria, tiempos de ejecución, etc.
- Configuración de supervisor para trabajadores en segundo plano.

## Créditos

Script original basado en:
- La guía oficial de instalación de MISP: https://misp.github.io/MISP
- AutoMISP de @da667: https://github.com/da667/AutoMISP/blob/master/auto-MISP-ubuntu.sh
- MISP-docker por @ostefano: https://github.com/MISP/MISP-docker

Traducción y mejoras por David Espinoza para cybeersecurity.
