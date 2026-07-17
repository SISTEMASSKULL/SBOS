# SBOS bi18n — mensajes localizados en español (Bolivia)
# Fluent Project v0.16 — concordancia con CLDR plural rules
# Recargable en SIGHUP: editar este archivo y enviar SIGHUP al daemon.

-brand-name = SBOS bi18n

# ── Errores de validación de documentos ───────────────────────────────────────
error-ci-invalido = Cédula de identidad boliviana inválida. Formato esperado: { $ejemplo }.
error-nit-invalido = NIT boliviano inválido. Debe tener entre 7 y 12 dígitos.
error-dni-invalido = DNI argentino inválido. Debe contener 7 u 8 dígitos.
error-cuit-invalido = CUIT/CUIL argentino inválido. Formato esperado: { $ejemplo }.
error-cpf-invalido = CPF brasileño inválido. Debe contener 11 dígitos.
error-cnpj-invalido = CNPJ brasileño inválido. Debe contener 14 dígitos.
error-passport-invalido = Pasaporte inválido. Formato esperado: { $ejemplo }.

# ── Errores de validación de contacto ─────────────────────────────────────────
error-email-invalido = Dirección de correo electrónico inválida (RFC 5321).
error-telefono-invalido = Número de teléfono inválido: { $detalle }.
error-telefono-pais = Número de teléfono no válido para el país indicado.

# ── Errores de configuración y locale ─────────────────────────────────────────
error-documento-no-soportado = Tipo de documento no soportado para el país '{ $pais }'.
error-locale-invalido = Locale BCP 47 inválido: '{ $locale }'.

# ── Mensajes de estado del daemon ─────────────────────────────────────────────
paises-cargados = { $n ->
    [one] 1 país cargado
   *[other] { $n } países cargados
}

regla-pais-cargada = Reglas del país '{ $iso }' cargadas.
recarga-exitosa = Recarga de configuración completada: { $n ->
    [one] 1 archivo
   *[other] { $n } archivos
}.
