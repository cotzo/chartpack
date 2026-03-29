# Certificates

TLS Certificates are defined in the `networking.certificates` map. Creates [cert-manager](https://cert-manager.io/) Certificate resources that automatically provision and renew TLS certificates.

Each entry is named `<fullname>-<key>`. The `secretName` defaults to `<fullname>-<key>-tls` — reference this secret in your Ingress TLS config.

## Basic Usage

```yaml
networking:
  certificates:
    app-tls:
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames:
        - app.example.com
        - www.example.com

  ingresses:
    public:
      className: nginx
      tls:
        - secretName: my-app-app-tls-tls    # matches certificate's auto-generated secretName
          hosts:
            - app.example.com
      hosts:
        - host: app.example.com
          paths:
            - path: /
              pathType: Prefix
```

## Custom Secret Name

Override the auto-generated secret name:

```yaml
networking:
  certificates:
    app-tls:
      issuerRef:
        name: letsencrypt-prod
      secretName: app-tls-secret         # use this in ingress tls[].secretName
      dnsNames:
        - app.example.com
```

## Duration and Renewal

```yaml
networking:
  certificates:
    app-tls:
      issuerRef:
        name: letsencrypt-prod
      dnsNames:
        - app.example.com
      duration: 2160h                    # 90 days
      renewBefore: 360h                  # renew 15 days before expiry
```

## Private Key Settings

```yaml
networking:
  certificates:
    app-tls:
      issuerRef:
        name: letsencrypt-prod
      dnsNames:
        - app.example.com
      privateKey:
        algorithm: ECDSA                 # RSA | ECDSA | Ed25519
        size: 256                        # key size in bits
        rotationPolicy: Always           # Never | Always
```

## Auto-Mount to Containers

Set `mount.path` to automatically mount the TLS certificate into all containers as a read-only volume:

```yaml
networking:
  certificates:
    app-tls:
      issuerRef:
        name: letsencrypt-prod
      dnsNames:
        - app.example.com
      mount:
        path: /etc/tls
```

The certificate files (`tls.crt`, `tls.key`, `ca.crt`) will be available at `/etc/tls/` in every container. No need to manually configure mounts or mark the secret as external.

If `mount` is not set, the certificate Secret is still created but not mounted — useful when only the Ingress controller needs it.

## Namespace-Scoped Issuer

Use `kind: Issuer` for namespace-scoped issuers:

```yaml
networking:
  certificates:
    internal-tls:
      issuerRef:
        name: internal-ca
        kind: Issuer
      dnsNames:
        - app.internal.example.com
```

## All Options

| Field | Default | Description |
|-------|---------|-------------|
| `issuerRef.name` | **required** | Issuer or ClusterIssuer name |
| `issuerRef.kind` | `ClusterIssuer` | `Issuer` or `ClusterIssuer` |
| `issuerRef.group` | `cert-manager.io` | Issuer API group |
| `secretName` | `<fullname>-<key>-tls` | Target Secret for the TLS cert |
| `mount.path` | | Auto-mount cert to all containers at this path (read-only) |
| `commonName` | | Certificate common name |
| `dnsNames` | | DNS subject alternative names |
| `ipAddresses` | | IP address SANs |
| `uris` | | URI SANs |
| `emailAddresses` | | Email SANs |
| `duration` | `2160h` (90d) | Certificate lifetime |
| `renewBefore` | `360h` (15d) | Renew this long before expiry |
| `privateKey` | | Key algorithm, size, encoding, rotation |
| `usages` | | Key usage extensions |
| `isCA` | `false` | Mark as certificate authority |
| `subject` | | X.509 subject fields (orgs, countries, etc.) |
| `keystores` | | Additional keystore formats (JKS, PKCS12) |
| `secretTemplate` | | Labels/annotations for the generated Secret |

[cert-manager Certificate reference](https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate) |
[cert-manager documentation](https://cert-manager.io/docs/)
