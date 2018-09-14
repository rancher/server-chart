# rancher

Chart for installing Rancher Server to manage Kubernetes clusters across providers.

Rancher Resources:

* Rancher Docs: https://rancher.com/docs/rancher/v2.x/en/
* GitHub: https://github.com/rancher/rancher
* DockerHub Images: https://hub.docker.com/r/rancher/rancher

> NOTE: We recommend a small dedicated cluster for running Rancher Server.  Rancher will integrate with the local cluster and use the clusters etcd database as its database.

## Prerequisites

### Add the Chart Repo

Add the Rancher chart repository.

```shell
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
```

### Install `cert-manager`

Rancher relies on `cert-manager` from the Kubernetes Helm Stable catalog to issue self-signed or LetsEncrypt certificates.

Install `cert-manager` from the Helm stable catalog.

```shell
helm install stable/cert-manager --name cert-manager --namespace kube-system
```

## Installing Rancher

Rancher server is designed to be "secure by default" and requires SSL/TLS configuration.  There are two options for where to terminate SSL.

* `ingress` - Provide a certificate, use LetsEncrypt or use Rancher's generated CA for TLS on Kubernetes Ingress.
* `external` - Configure certificates on a external load balancer or other proxy.

### (Default) TLS Configured at the Ingress

There are three options for the source of the certificate.

* `rancher` - (Default) Use Rancher generated CA/Certificates.
* `letsEncrypt` - Use [LetsEncrypt](https://letsencrypt.org/) to issue a cert.
* `secret` - Configure a Kubernetes Secret with your certificate files.

#### (Default) Rancher Generated Certificates

The default is to use the Rancher to generate a CA and `cert-manager` to issue the certificate for access to the Rancher server interface.

The only requirement is to set the `hostname` that Rancher will listen on.

```shell
helm install rancher-stable/rancher --name rancher --namespace cattle-system \
--set hostname=rancher.my.org
```

#### LetsEncrypt

Use LetsEncrypt's free service to issue trusted SSL certs. This configuration uses http validation so the Ingress must have a Public DNS record and be accessible from the internet.

Set `hostname`, `ingress.tls.source=letEncrypt` and LetsEncrypt options.

```shell
helm install rancher-stable/rancher --name rancher --namespace cattle-system \
--set hostname=rancher.my.org \
--set ingress.tls.source=letsEncrypt \
--set letsEncrypt.email=me@example.org
```

#### Ingress Certs from Files (Kubernetes Secret)

Create Kubernetes Secrets from your own cert for Rancher to use.

> NOTE: The common name for the cert will need to match the `hostname` option or the ingress controller will fail to provision the site for Rancher.

Set `hostname` and `ingress.tls.source=secret`

> NOTE: If you are using a Private CA signed cert, add `--set privateCA=true`

```shell
helm install rancher-stable/rancher --name rancher --namespace cattle-system \
--set hostname=rancher.my.org \
--set ingress.tls.source=secret
```

Now that Rancher is running, see [Adding TLS Secrets](#Adding-TLS-Secrets) to publish the certificate files so Rancher and the Ingress Controller can use them.

## Adding TLS Secrets

Kubernetes will create all the objects and services for Rancher, but it will not become available until we populate the `rancher-tls` secret in the `cattle-system` namespace with the certificate and key.

Combine the server certificate followed by the intermediate cert chain your CA provided into a file named `tls.crt`. Copy your key into a file name `tls.key`.

Use `kubectl` with the `tls` type to create the secrets.

```shell
kubectl -n cattle-system create secret tls tls-rancher-ingress --cert=./tls.crt --key=./tls.key
```

### Private CA Signed - Additional Steps

Rancher will need to have a copy of the CA cert to include when generating agent configs.

Copy the CA cert into a file named `cacerts.pem` and use `kubectl` to create the `tls-ca` secret in the `cattle-system` namespace.

```shell
kubectl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem
```

## Common Options

| Option | Default Value | Description |
| --- | --- | --- |
| `hostname` | "" | `string` - the Fully Qualified Domain Name for your Rancher Server |
| `ingress.tls.source` | "rancher" | `string` - Where to get the cert for the ingress. - "rancher, letsEncrypt, secret" |
| `letsEncrypt.email` | "none@example.com" | `string` - Your email address |
| `letsEncrypt.environment` | "production" | `string` - Valid options: "staging, production" |
| `privateCA` | false | `bool` - Set to true if your cert is signed by a private CA |
| `replicas` | 1 | `int` - number of rancher server replicas |

## Other Options

| Option | Default Value | Description |
| --- | --- | --- |
| `additionalTrustedCAs` | false | `bool` - See [Additional Trusted CAs](#additional-trusted-cas) |
| `debug` | false | `bool` - set debug flag on rancher server |
| `imagePullSecrets` | [] | `list` - list of names of Secret resource containing private registry credentials |
| `noProxy` | "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16" | `string` - comma separated list of domains/IPs that will not use the proxy |
| `proxy` | "" | `string` - HTTP[S] proxy server for Rancher |
| `resources` | {} | `map` - rancher pod resource requests & limits |
| `rancherImage` | "rancher/rancher" | `string` - rancher image source |
| `rancherImageTag` | same as chart version | `string` - rancher/rancher image tag |

## Private or Air Gap Registry

You can point to a private registry for an "Air Gap" install.

### Create Registry Secret

Create a Registry secret in the `cattle-system` namespace. Check out the [Kubernetes Docs](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) for more info.

### Registry Options

Add the `rancherImage` to point to your private registry image and `imagePullSecrets` to your install command.

```shell
--set rancherImage=private.reg.org:5000/rancher/rancher \
--set imagePullSecrets[0].name=secretName
```

### HTTP[S] Proxy

Rancher requires internet access for some functionality (helm charts). Set `proxy` to your proxy server. Add your domain name or ip exceptions to the `noProxy` list. Make sure your worker cluster `controlplane` nodes are included in this list.

```shell
--set proxy="http://<username>:<password>@<proxy_url>:<proxy_port>/"
--set noProxy="127.0.0.0/8\,10.0.0.0/8\,172.16.0.0/12\,192.168.0.0/16"
```

## Additional Trusted CAs

If you have private registries, catalogs or a proxy that intercepts certificates, you may need to add additional trusted CAs to Rancher.

```shell
--set additionalTrustedCAs=true
```

Once the Rancher deployment is created, copy your CA certs in pem format into a file named `ca-additional.pem` and use `kubectl` to create the `tls-ca-additional` secret in the `cattle-system` namespace.

```shell
kubectl -n cattle-system create secret generic tls-ca-additional --from-file=ca-additional.pem
```

## Connecting to Rancher

Rancher should now be accessible. Browse to `https://whatever.hostname.is.set.to`
