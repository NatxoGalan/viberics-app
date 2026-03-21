#!/bin/bash

# 1. Clonar Flutter (solo la versión estable y lo mínimo necesario)
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# 2. Añadir Flutter al PATH del servidor
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Descargar dependencias y compilar
flutter doctor
flutter build web --release