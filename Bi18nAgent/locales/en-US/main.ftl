# SBOS bi18n — localized messages in English (United States)
# Fluent Project v0.16

-brand-name = SBOS bi18n

error-ci-invalido = Invalid Bolivian national ID. Expected format: { $ejemplo }.
error-nit-invalido = Invalid Bolivian NIT. Must be between 7 and 12 digits.
error-dni-invalido = Invalid Argentine DNI. Must contain 7 or 8 digits.
error-cuit-invalido = Invalid Argentine CUIT/CUIL. Expected format: { $ejemplo }.
error-cpf-invalido = Invalid Brazilian CPF. Must contain 11 digits.
error-cnpj-invalido = Invalid Brazilian CNPJ. Must contain 14 digits.
error-passport-invalido = Invalid passport. Expected format: { $ejemplo }.

error-email-invalido = Invalid email address (RFC 5321).
error-telefono-invalido = Invalid phone number: { $detalle }.
error-telefono-pais = Phone number not valid for the indicated country.

error-documento-no-soportado = Document type not supported for country '{ $pais }'.
error-locale-invalido = Invalid BCP 47 locale: '{ $locale }'.

paises-cargados = { $n ->
    [one] 1 country loaded
   *[other] { $n } countries loaded
}

regla-pais-cargada = Country rules for '{ $iso }' loaded.
recarga-exitosa = Configuration reload completed: { $n ->
    [one] 1 file
   *[other] { $n } files
}.
