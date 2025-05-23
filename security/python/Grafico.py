import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import random
import os

# Simulación de datos de amenazas
fechas = [datetime.now() - timedelta(minutes=10*i) for i in reversed(range(10))]
niveles = [random.choice([0, 1, 2, 3]) for _ in fechas]  # 0: normal, 3: crítica

# Etiquetas de nivel
niveles_str = ['Normal', 'Baja', 'Media', 'Crítica']
colores = ['green', 'yellow', 'orange', 'red']

# Crear gráfico
plt.figure(figsize=(10, 5))
for i, nivel in enumerate(niveles):
    plt.plot(fechas[i], nivel, 'o', label=niveles_str[nivel], color=colores[nivel])

plt.yticks(ticks=[0, 1, 2, 3], labels=niveles_str)
plt.ylim(-0.5, 3.5)
plt.xlabel("Tiempo")
plt.ylabel("Nivel de amenaza")
plt.title("🔒 Gráfico de actividad sospechosa en la sesión WSL")
plt.grid(True)

# Evitar leyendas repetidas
handles, labels = plt.gca().get_legend_handles_labels()
by_label = dict(zip(labels, handles))
plt.legend(by_label.values(), by_label.keys())

# Guardar gráfico
output_path = os.path.expanduser("~/wsl_threat_report.png")
plt.savefig(output_path)
plt.close()

output_path