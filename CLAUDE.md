# Reglas de desarrollo de la app

- Backend first (aplica a ambos flavors): todo cambio de la app se hace primero en el backend (endpoints, lógica, datos) y después en la app. La app solo consume lo que el backend ya tiene listo.
- En la medida de lo posible, el procesamiento va del lado del backend (cálculos, validaciones, reglas de negocio, decisiones de qué mostrar). Así, si algo cambia, se actualiza el servidor sin tener que publicar una nueva versión de la app. La app debe ser lo más delgada posible: mostrar lo que el backend le dice y enviar acciones. Es una orientación, no un absoluto: habrá casos donde no se pueda (sensores del teléfono, funcionamiento sin conexión, respuesta inmediata de la interfaz) y ahí la lógica puede vivir en la app.

# Flujo de ramas

- `development`: trabajo en curso. Las ramas de feature se crean desde aquí y regresan aquí.
- `staging`: pruebas previas a producción. Se promueve desde `development`.
- `main`: producción. Se promueve desde `staging`.
- Flujo de promoción: `development` → `staging` → `main`. Nunca se trabaja directo en `main`.
- Antes de compilar para producción verifica que `AppConfig.baseUrl` apunte a producción.
