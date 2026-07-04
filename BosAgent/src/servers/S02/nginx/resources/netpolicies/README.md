# NetworkPolicies — nginx (HOST S02)

## nginx NO es un pod K8s

nginx corre como **proceso systemd en el HOST Ubuntu 26.04** (S02), no como pod.
Las NetworkPolicies de Calico se aplican a pods en el cluster K8s.
Por tanto, esta ficha NO tiene NetworkPolicies YAML.

## Seguridad de red en nginx HOST

El aislamiento de red de nginx se gestiona por:

| Mecanismo | Descripción |
|-----------|-------------|
| **UFW** | Firewall del host. Solo :80 y :443 externos (SBOS-050: 3 puertos externos). |
| **nftables/iptables** | Configurado por BOS durante bootstrap. Deny-all de entrada excepto :22/:80/:443. |
| **nginx.conf** | stub_status solo en 127.0.0.1 (never external). Health check responde 200 sin datos sensibles. |

## Lo que SÍ tiene NetworkPolicy en K8s

Kong (pod en K8s) sí tiene NetworkPolicy en `servers/S02/kong/resources/netpolicies/`.
Todo tráfico que nginx delega a Kong (127.0.0.1:8000) entra al cluster y
queda sujeto a las políticas Calico de Kong.
