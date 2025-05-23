# 🌅 Ocaso‑Security

Ocaso‑Security es una plataforma modular de protección digital, introspección y control ético, diseñada para fortalecer la privacidad, la trazabilidad y la resiliencia. Combina un sistema de **autenticación por PIN**, paneles visuales privados, monitoreo de red y defensa cibernética local mediante scripts especializados.

> *“No se trata solo de proteger máquinas. Se trata de proteger momentos, emociones y decisiones.”*

Opera en sistemas **Windows** y está lista para desplegarse en entornos **AWS**.

---

## 🧠 Características Clave

* **Autenticación Segura:** Inicio de sesión sin contraseñas mediante PIN con validación de IP y rol por usuario.
* **Introspección y Control:** Suspensión temporal del sistema con guía reflexiva incluida.
* **Visualización y Trazabilidad:**

  * Dashboard privado con visualización de eventos y métricas.
  * Logs con firma SHA‑256 y evidencia en formato JSON.
* **Alertas y Notificaciones:** Conexión opcional con Telegram para alertas.
* **Integración Cloud:** Preparado para AWS (EC2, RDS, Lambda, CloudWatch, S3).
* **Diseño Modular:** Estructura organizada en `tools/`, `scripts/`, `bot/`, `lambda/`, `middleware/`.
* **Defensa Activa:** Incluye el script defensivo **BlindajeTotal.ps1**.

---

## ⚔️ BlindajeTotal.ps1 — Defensa Extrema para Windows

**BlindajeTotal.ps1** es un script especializado para Windows 10/11 que ofrece:

### Control de Tráfico de Red

* Bloquea todo el tráfico de red por defecto, permitiendo solo el tráfico hacia/desde IPs autorizadas.
* Verifica la configuración de DNS y corta la conexión de red ante configuraciones sospechosas.
* Detecta y bloquea conexiones TCP salientes a puertos no permitidos.
* Detecta el uso de VPNs analizando el ISP y país de origen de las conexiones (GeoIP).
* Lanza trampas (honeypots) en la red para detectar actividad maliciosa.

### Análisis y Respuesta del Sistema

* Finaliza procesos desconocidos o sin firma válida y emite alertas.

### Reportes y Alertas

* Genera reportes detallados en formato HTML.

* Crea logs con opción a cifrado.

* Incluye un módulo para el envío de alertas a sistemas externos (endpoints de emergencia, webhooks, etc.).

* **Portabilidad:** Compatible con la compilación a un archivo `.exe` mediante *ps2exe*.

* **Estado Actual:** Fase experimental, adaptándose para una integración óptima con infraestructura en la nube.

---

## 🚀 Instalación y Uso Local (Ejemplo con *OcasoNotes*)

```bash
git clone https://github.com/wkeysam/OcasoNotes.git  # Verifica que sea el repo correcto
cd ocaso                    # O el nombre del directorio clonado
python3 -m venv venv
source venv/bin/activate    # En Windows: venv\Scripts\activate
pip install -r requirements.txt
```

---

## 📂 Estructura del Proyecto

```text
Ocaso-Security/
├── .vscode/
├── app/
├── lambda/
├── middleware/
├── migrations/
├── scripts/
├── security/
│   └── Blindaje/
│       ├── Powershell.ps1
│       └── Modules/
├── tests/
├── tools/
├── .dockerignore
├── .gitignore
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── Dockerfile
├── LICENSE
├── README.md
├── SECURITY.md
├── docker-compose.yml
├── entrypoint.sh
├── pytest.ini
├── requirements.txt
└── run.py
```

---

## 🛡️ Uso de BlindajeTotal.ps1 en AWS EC2 (Windows)

Para proteger una instancia EC2 Windows con **BlindajeTotal.ps1**:

1. **Configura la auto‑ejecución al inicio** mediante *Task Scheduler*.
2. **Acción:** `powershell.exe`
3. **Argumentos:**

   ```powershell
   -ExecutionPolicy Bypass -File "C:\ruta\completa\a\security\BlindajeTotal.ps1" -Hardening
   ```

---

## 🔐 Licencia

Este proyecto es software propietario. Copyright (c) [2025] [Samuel Enrique Garcia Díaz]. Todos los derechos reservados.
Consulte el archivo `LICENSE` para más detalles.

---

## 🤝 Autor

**Samuel Enrique García Díaz**
✉️ [sam.dgarcia02@gmail.com](mailto:sam.dgarcia02@gmail.com)
💻 [@wkeysam](https://github.com/wkeysam)

---

## ❤️ Apóyame en Patreon

Si este proyecto te ha ayudado o te inspira, considera apoyarme en [Patreon](https://patreon.com/wkeysam):

* Acceso anticipado a funciones nuevas
* Participación en decisiones del *roadmap*
* Menciones en futuras versiones

---

## 🏷️ Etiquetas

`#PowerShell` `#Cyberdefensa` `#Python` `#Flask` `#AWS` `#PIN` `#Reflexión` `#Firewall` `#GeoIP` `#OpenSource` `#MentalHealth` `#Hardening` `#VPNDetection` `#Security` `#CloudInfra`


