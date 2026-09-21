# Detecta teclados en Windows.
#   powershell -ExecutionPolicy Bypass -File installers\windows\detectar_teclados.ps1
#
# La columna InstanceId identifica el dispositivo fisico (incluye VID/PID).

Get-PnpDevice -Class Keyboard -Status OK |
    Select-Object FriendlyName, InstanceId |
    Format-Table -AutoSize
