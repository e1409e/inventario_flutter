# 📦 Triple AAA | Warehouse & Inventory System (`inventario_pro`)

![Flutter](https://img.shields.io/badge/Flutter-%5E3.11.5-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Turso](https://img.shields.io/badge/Turso-libSQL%20Cloud-4FF8D2?logo=turso&logoColor=black)
![Drift](https://img.shields.io/badge/Drift-SQLite%20Local%20Vault-blue?logo=sqlite&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20BLoC-purple)

Sistema multiplataforma de gestión de almacén, control de existencias en tiempo real y auditoría de movimientos diseñado para **Inversiones Las 3 AAA C.A. (Triple AAA Food Distribution)**.

Construido bajo una arquitectura **Cloud-First** con **Turso (libSQL)** como motor transaccional distribuido y **Drift (SQLite)** como bóveda local de archivo histórico y contingencia.

---

## 🚀 Características Principales

* **Control de Stock en Tiempo Real:** Sincronización paralela de catálogo maestro y existencias entre estaciones de escritorio (Linux/Windows) y dispositivos móviles (Android).
* **Registro Atómico de Movimientos con Validación en Vivo:**
  * Flujos diferenciados de **Entradas (`inbound`)** y **Salidas (`outbound`)** mediante transacciones SQL ACID.
  * **Categorización Operativa:**
    * *Salidas:* `Facturas`, `Tienda`, `Deposito 2`, `Averia`, `Ajuste de inventario`, `Prestamo`, `Sin Definir`.
    * *Entradas:* `Entrega`, `Devolucion`, `Traslado`, `Prestadas`, `Sin Definir`.
  * **Fecha Contable Retroactiva:** Soporte para asentar tickets diferidos en su fecha operativa real.
  * **Prevención de Sobregiro:** Cálculo proyectado en tiempo real que bloquea salidas superiores al stock disponible.
* **Historial Paginado en Servidor (Server-Side Pagination):** Consultas optimizadas mediante `LIMIT / OFFSET` e índices B-Tree para mantener un consumo mínimo de lecturas (`Rows Read`) en la nube.
* **Reportería y Auditoría Diaria:**
  * Generación de cierres diarios consolidados por fecha, flujo y categoría específica.
  * Exportación nativa a **PDF (formato de impresión/auditoría)** y **Excel (CSV con codificación UTF-8 BOM)**.
* **Bóveda Local y Depuración Histórica (> 90 días):**
  * Asistente de mantenimiento que respalda movimientos antiguos en **4 capas** (Base de datos SQLite local + archivo JSON estructurado + Excel CSV + Reporte PDF) antes de liberar espacio en la nube sin afectar el stock actual.

---

## 🏗️ Arquitectura del Proyecto

El código sigue los principios de **Clean Architecture** divididos en tres capas desacopladas e inyectadas mediante `get_it`:

```text
lib/
├── core/
│   ├── entities/          # Reglas y modelos de dominio puros (Product, StockStatus, InventoryTransaction)
│   ├── repositories/      # Contratos e interfaces abstractas (InventoryRepository)
│   └── utils/             # Generadores de reportes PDF, Excel (CSV) y exportador de respaldos
├── data/
│   ├── datasources/       # Clientes de datos: TursoDataSource (libSQL) y LocalDatabase (Drift SQLite)
│   ├── models/            # Serializadores JSON / Drift Companion (ProductModel, TransactionModel)
│   └── repositories/      # Implementación de repositorios y lógica de contingencia/archivado
├── presentation/
│   ├── screen/            # Vistas principales (Dashboard, Inventory, Transactions, Catalog)
│   ├── state/             # Gestión de estado reactivo con Cubit (InventoryCubit, InventoryState)
│   └── widgets/           # Componentes modulares (MovementForm, DailyReportSheet, ProductInventoryCard)
├── injection_container.dart # Localizador de servicios e inicialización de clientes
└── main.dart              # Punto de entrada y configuración de tema global
```

---

## ⚡ Optimización de Base de Datos (Turso / libSQL)

El datasource remoto inicializa y verifica de forma automática el esquema y los índices B-Tree esenciales para evitar escaneos completos de tabla (Full Table Scans):

```sql
CREATE INDEX IF NOT EXISTS idx_tx_items_tx_id ON transaction_items(transaction_id);
```
```sql
CREATE INDEX IF NOT EXISTS idx_tx_timestamp ON transactions(timestamp DESC);
```
```sql
CREATE INDEX IF NOT EXISTS idx_tx_type_timestamp ON transactions(type, timestamp DESC);
```
```sql
CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category);
```
```sql
CREATE INDEX IF NOT EXISTS idx_stock_prod_id ON stock(product_id);
```

Adicionalmente, las operaciones de registro de movimientos actualizan el estado de existencias directamente en memoria tras confirmar el COMMIT remoto, eliminando lecturas redundantes del catálogo tras cada transacción.

---
## ⚙️ Requisitos e Instalación

**1. Prerrequisitos**

* Flutter SDK: ^3.11.5

* Instancia de Turso (libSQL): URL de conexión y Token de autenticación.

* Dependencias de compilación en Linux (Fedora/Ubuntu): clang, cmake, ninja-build, gtk3-devel.

**2. Variables de Entorno**

Crea un archivo .env en la raíz del proyecto con tus credenciales de Turso:
```bash
TURSO_URL=libsql://tu-base-de-datos.turso.io
TURSO_TOKEN=tu_token_jwt_de_turso
```

**3. Ejecución en Desarrollo**
```bash
# Instalar dependencias
flutter pub get

# Verificar análisis estático de código
flutter analyze

# Ejecutar en escritorio Linux
flutter run -d linux
```

---
## 📦 Compilación para Producción (Release)

**Linux (Desktop)**
```bash
flutter build linux --release
# El ejecutable compilado se generará en:
# build/linux/x64/release/bundle/
```

**Android (APK)**
```bash
flutter build apk --release --split-per-abi
# Los instaladores optimizados se generarán en:
# build/app/outputs/flutter-apk/
```
