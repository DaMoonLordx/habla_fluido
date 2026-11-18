# ============================================================================
#  Habla Fluido - capturas del ciclo TDD en ORDEN (ROJO -> VERDE) por ronda
#
#  Uso (desde la carpeta del proyecto, en PowerShell o CMD):
#     powershell -ExecutionPolicy Bypass -File .\capturas_habla_fluido.ps1
#  Opcional (solo rojos "de compilación", sin los de aserción):
#     powershell -ExecutionPolicy Bypass -File .\capturas_habla_fluido.ps1 -SinAserciones
#
#  En cada pantalla el script se detiene: toma tu captura (Win + Shift + S)
#  y presiona Enter. Todo se guarda también en la carpeta capturas\ (.txt).
#  Si el script se corta, vuelve a ejecutarlo: primero restaura lo que ocultó.
# ============================================================================
param([switch]$SinAserciones)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $raiz
$logs = Join-Path $raiz 'capturas'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:contador = 0

# --- Si una corrida anterior se cortó, deja todo como estaba -----------------
Get-ChildItem -Path $raiz -Recurse -Force -Include '*.bak', '*.orig' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\(\.dart_tool|node_modules|build)\\' } |
    ForEach-Object {
        $destino = $_.FullName -replace '\.(bak|orig)$', ''
        if ($_.Extension -eq '.orig') {
            Move-Item -Force $_.FullName $destino
        } elseif (-not (Test-Path $destino)) {
            Move-Item $_.FullName $destino
        }
    }

function Encabezado($texto, $color) {
    Clear-Host
    Write-Host ('=' * 72) -ForegroundColor $color
    Write-Host ("  " + $texto) -ForegroundColor $color
    Write-Host ('=' * 72) -ForegroundColor $color
    Write-Host ''
}

function Pausa($mensaje) {
    Write-Host ''
    Read-Host ">> $mensaje  (Enter para continuar)" | Out-Null
}

function Ocultar($rutas) {
    foreach ($r in $rutas) {
        $p = Join-Path $raiz $r
        if (Test-Path $p) { Rename-Item -Path $p -NewName ((Split-Path $p -Leaf) + '.bak') }
    }
}

function Restaurar($rutas) {
    foreach ($r in $rutas) {
        $p = Join-Path $raiz $r
        if (Test-Path ($p + '.bak')) { Rename-Item -Path ($p + '.bak') -NewName (Split-Path $p -Leaf) }
    }
}

# Cambia un texto del archivo para que una regla "se rompa" (guarda copia .orig)
function Romper($ruta, $buscar, $reemplazo) {
    $p = Join-Path $raiz $ruta
    Copy-Item $p ($p + '.orig') -Force
    $txt = [System.IO.File]::ReadAllText($p, $utf8)
    if (-not $txt.Contains($buscar)) {
        Write-Host "No encontré el texto a romper en $ruta (¿cambiaste el archivo?)." -ForegroundColor Yellow
        return $false
    }
    [System.IO.File]::WriteAllText($p, $txt.Replace($buscar, $reemplazo), $utf8)
    return $true
}

function Desromper($ruta) {
    $p = Join-Path $raiz $ruta
    if (Test-Path ($p + '.orig')) { Move-Item -Force ($p + '.orig') $p }
}

function Probar($tipo, $prueba, $nombreLog) {
    $script:contador++
    $archivo = Join-Path $logs ('{0:D2}_{1}.txt' -f $script:contador, $nombreLog)
    if ($tipo -eq 'node') {
        Push-Location (Join-Path $raiz 'proxy')
        Write-Host "PS> node --test $prueba" -ForegroundColor DarkGray
        node --test $prueba 2>&1 | Tee-Object -FilePath $archivo
        Pop-Location
    } else {
        Write-Host "PS> flutter test --reporter expanded $prueba" -ForegroundColor DarkGray
        flutter test --reporter expanded $prueba 2>&1 | Tee-Object -FilePath $archivo
    }
}

# --- Un ciclo ROJO (falta el código) -> VERDE (se restaura) -------------------
function Ronda($titulo, $tipo, $prueba, $ocultar, $nombreLog) {
    Encabezado "$titulo  |  ROJO: la prueba existe, el código todavía no" 'Red'
    Ocultar $ocultar
    Probar $tipo $prueba "${nombreLog}_rojo"
    Pausa 'Toma la captura del ROJO'
    Restaurar $ocultar
    Encabezado "$titulo  |  VERDE: se escribió el código" 'Green'
    Probar $tipo $prueba "${nombreLog}_verde"
    Pausa 'Toma la captura del VERDE'
}

# --- Un ciclo ROJO (una regla rota, falla una aserción) -> VERDE --------------
function RondaRota($titulo, $tipo, $prueba, $ruta, $buscar, $reemplazo, $nombreLog) {
    if ($SinAserciones) { return }
    Encabezado "$titulo  |  ROJO: una regla se rompe y la prueba lo detecta" 'Red'
    if (Romper $ruta $buscar $reemplazo) {
        Probar $tipo $prueba "${nombreLog}_rojo"
        Pausa 'Toma la captura del ROJO (aserción fallida)'
        Desromper $ruta
        Encabezado "$titulo  |  VERDE: regla restaurada" 'Green'
        Probar $tipo $prueba "${nombreLog}_verde"
        Pausa 'Toma la captura del VERDE'
    } else {
        Desromper $ruta
        Pausa 'Se omite este paso'
    }
}

# ============================= INICIO ======================================
Encabezado 'Habla Fluido: preparación (no necesita captura)' 'Cyan'
flutter pub get
Pausa 'Listo. A partir de aquí cada pantalla es una captura'

# --- Ronda 2: comparador ------------------------------------------------------
Ronda 'RONDA 2 - Comparador' 'flutter' 'test\comparador_test.dart' `
    @('lib\dominio\comparador.dart') 'r2_comparador'
RondaRota 'RONDA 2 - Comparador' 'flutter' 'test\comparador_test.dart' `
    'lib\dominio\comparador.dart' '0.25 * _cuenta(EstadoPalabra.sobrante)' '0.0 * _cuenta(EstadoPalabra.sobrante)' `
    'r2_comparador_aserc'

# --- Rondas 3 y 4: SM-2, progreso y plan diario (comparten el mismo test) ----
Ronda 'RONDAS 3 y 4 - Repaso SM-2, progreso y plan diario' 'flutter' 'test\repaso_progreso_test.dart' `
    @('lib\dominio\repaso.dart', 'lib\dominio\progreso.dart', 'lib\dominio\plan_diario.dart') 'r3_r4_repaso_progreso'
RondaRota 'RONDA 3 - SM-2: el segundo intervalo deja de ser 6 días' 'flutter' 'test\repaso_progreso_test.dart' `
    'lib\dominio\repaso.dart' '(reps == 2 ? 6 :' '(reps == 2 ? 7 :' 'r3_sm2_aserc'
RondaRota 'RONDA 4 - EMA: el último intento pesa 50% en vez de 30%' 'flutter' 'test\repaso_progreso_test.dart' `
    'lib\dominio\reglas.dart' 'pesoUltimoIntento = 0.3' 'pesoUltimoIntento = 0.5' 'r4_ema_aserc'

# --- Ronda 6: proxy en Node ---------------------------------------------------
Ronda 'RONDA 6 - Proxy de la IA (Node)' 'node' 'test\proxy.test.js' `
    @('proxy\prompt.js', 'proxy\server.js') 'r6_proxy'
RondaRota 'RONDA 6 - Proxy: se acepta texto de 5000 caracteres' 'node' 'test\proxy.test.js' `
    'proxy\prompt.js' 'MAX_CARACTERES = 500' 'MAX_CARACTERES = 5000' 'r6_proxy_aserc'

# --- Rondas 5 y 7: contrato del tutor, tutor simulado y cliente HTTP ---------
Ronda 'RONDAS 5 y 7 - Contrato del tutor, tutor simulado y cliente HTTP' 'flutter' 'test\tutor_test.dart' `
    @('lib\dominio\tutor.dart', 'lib\datos\tutor_simulado.dart', 'lib\datos\tutor_http.dart') 'r5_r7_tutor'

# --- Ronda 9: ViewModels ------------------------------------------------------
Ronda 'RONDA 9 - ViewModels (pronunciación, dictado, lectura, escritura, conversación, repaso)' 'flutter' 'test\vms_test.dart' `
    @('lib\presentacion\vm') 'r9_viewmodels'

# --- Final: todo junto --------------------------------------------------------
Encabezado 'FINAL - Todas las pruebas en verde (Dart)' 'Green'
$script:contador++
flutter test --reporter expanded 2>&1 | Tee-Object -FilePath (Join-Path $logs ('{0:D2}_final_flutter.txt' -f $script:contador))
Pausa 'Toma la captura final de Dart'

Encabezado 'FINAL - Todas las pruebas en verde (proxy Node)' 'Green'
Push-Location (Join-Path $raiz 'proxy')
$script:contador++
node --test 2>&1 | Tee-Object -FilePath (Join-Path $logs ('{0:D2}_final_proxy.txt' -f $script:contador))
Pop-Location
Pausa 'Toma la captura final del proxy'

Encabezado 'Terminaste. Tus textos de respaldo están en la carpeta capturas\' 'Cyan'
