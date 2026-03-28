# RBAC

## Service Account

```yaml
rbac:
  serviceAccount:
    create: true
    name: ""                       # defaults to <fullname>
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-role
    labels: {}
    automountServiceAccountToken: true
    imagePullSecrets: []
```

[ServiceAccount reference](https://kubernetes.io/docs/concepts/security/service-accounts/)

## Roles & Bindings

All RBAC resources are maps. Named `<fullname>-<key>`.

RoleBinding/ClusterRoleBinding `roleRef.name` is auto-prefixed to match chart-managed roles. Subjects default to the chart's ServiceAccount.

```yaml
rbac:
  roles:
    configmap-reader:
      rules:
        - apiGroups: [""]
          resources: ["configmaps"]
          verbs: ["get", "list", "watch"]
    secret-reader:
      rules:
        - apiGroups: [""]
          resources: ["secrets"]
          verbs: ["get"]
          resourceNames: ["specific-secret"]

  clusterRoles:
    node-reader:
      rules:
        - apiGroups: [""]
          resources: ["nodes"]
          verbs: ["get", "list", "watch"]

  roleBindings:
    configmap-reader:
      roleRef:
        name: configmap-reader     # → <fullname>-configmap-reader
        kind: Role                 # defaults to Role
      # subjects: []               # defaults to chart's ServiceAccount

  clusterRoleBindings:
    node-reader:
      roleRef:
        name: node-reader          # → <fullname>-node-reader
        kind: ClusterRole          # defaults to ClusterRole
```

[RBAC reference](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
