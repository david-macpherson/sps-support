## Enable Secure turn SPS

## Prerequisites

You will need the following information before proceeding

- `<COREWEAVE_NAMESPACE>` the namespace where sps has been installed to
- `<REGION>` The region sps has been installed to
- `<REST_API_ACCESS_KEY>` The rest api access key generated

To obtain these

1. Log in to the [CoreWeave Cloud](https://cloud.coreweave.com/login)
2. Select Applications in the menu on the left
3. Select the deployed Scalable Pixel Streaming application
4. The `<COREWEAVE_NAMESPACE>` can be found when you click the current context drop down in the top right corner
5. The `<REGION>` can be found as the value in the `Installation Values` under common -> region
6. The `<REST_API_ACCESS_KEY>` can be found under the Application Secrets section under restapiaccesskey

## How to 

In order to configure SPS to enable secure TURN you will need to do the following, Alternatively refer to the scripts directory for an automated approach

### 1. Expose the sps-coturn deployment with a domain name

First we need to expose the sps-coturn pod with the following domain name `turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud`

Once the `<REGION>` and `<COREWEAVE_NAMESPACE>` has been obtained and substituted in the following command, it can be executed

**Linux**
```bash
kubectl patch service sps-coturn --type='json' -p='[{"op":"add","path":"/metadata/annotations/external-dns.alpha.kubernetes.io~1hostname","value":"turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud"}]'
```

**Windows Powershell**
```powershell
kubectl patch service sps-coturn --type="json" -p="[{\"op\":\"add\",\"path\":\"/metadata/annotations/external-dns.alpha.kubernetes.io~1hostname\",\"value\":\"turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud\"}]"
```

Once the command has been run it can take up to 10 mins for the DNS record to be propagated

### 2. Request a certificate

Next we will need to generate a certificate using lets encrypt

Once the `<REGION>` and `<COREWEAVE_NAMESPACE>` has been obtained and substituted in the following file it can be executed

**Linux**
```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: sps-coturn-<REGION>-tls
  namespace: <COREWEAVE_NAMESPACE>
  labels:
    app.kubernetes.io/name: sps-coturn-<REGION>-tls
spec:
  dnsNames:
    - turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: letsencrypt-prod
  secretName: sps-coturn-<REGION>-tls
  usages:
    - digital signature
    - key encipherment
EOF
```

**Windows Powershell**
```powershell
@"
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: sps-coturn-<REGION>-tls
  namespace: <COREWEAVE_NAMESPACE>
  labels:
    app.kubernetes.io/name: sps-coturn-<REGION>-tls
spec:
  dnsNames:
    - turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: letsencrypt-prod
  secretName: sps-coturn-<REGION>-tls
  usages:
    - digital signature
    - key encipherment
"@ | kubectl apply -f -
```
Once the command has been run it can take up to 5 mins for the secret to be created


### 3. Update the sps-coturn deployment to enable secure turn

Once the secret has been created we need to update the sps-coturn deployment to enable tls

Once the `<REGION>` and `<COREWEAVE_NAMESPACE>` has been obtained and substituted in the following command it can be executed

**For linux users**
```bash
kubectl patch deployment sps-coturn --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/volumeMounts","value":[{"name":"coturn-certs","readOnly":true,"mountPath":"/certs"}]},{"op":"add","path":"/spec/template/spec/volumes","value":[{"name":"coturn-certs","secret":{"secretName":"sps-coturn-<REGION>-tls"}}]},{"op":"replace","path":"/spec/template/spec/initContainers/0/env","value":[{"name":"EXTERNAL_IP","value":"turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud"},{"name":"PORT","value":"443"},{"name":"NAMESPACE","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}},{"name":"CREDENTIAL","valueFrom":{"configMapKeyRef":{"name":"sps-coturn","key":"credential"}}}]},{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["--log-file=stdout","--external-ip=$(HOST_IP)","--listening-ip=$(HOST_IP)","--relay-ip=$(HOST_IP)","--user=sps-coturn-user:$(CREDENTIAL)","--server-name=turnserver","--fingerprint","--listening-port=443","--tls-listening-port=443","--min-port=49152","--max-port=65535","--verbose","--realm=PixelStreaming","--lt-cred-mech","--no-multicast-peers","--denied-peer-ip=0.0.0.0-0.255.255.255","--denied-peer-ip=100.64.0.0-100.127.255.255","--denied-peer-ip=127.0.0.0-127.255.255.255","--denied-peer-ip=169.254.0.0-169.254.255.255","--denied-peer-ip=172.16.0.0-172.31.255.255","--denied-peer-ip=192.0.0.0-192.0.0.255","--denied-peer-ip=192.0.2.0-192.0.2.255","--denied-peer-ip=192.88.99.0-192.88.99.255","--denied-peer-ip=198.18.0.0-198.19.255.255","--denied-peer-ip=198.51.100.0-198.51.100.255","--denied-peer-ip=203.0.113.0-203.0.113.255","--denied-peer-ip=240.0.0.0-255.255.255.255","--cert /certs/tls.crt","--pkey /certs/tls.key"]},{"op":"replace","path":"/spec/template/spec/containers/0/env","value":[{"name":"PORT","value":"443"},{"name":"HOST_IP","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"status.podIP"}}},{"name":"NAMESPACE","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}},{"name":"CREDENTIAL","valueFrom":{"configMapKeyRef":{"name":"sps-coturn","key":"credential"}}}]}]'
```

**Windows Powershell**
```powershell
kubectl patch deployment sps-coturn --type="json" -p="[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/volumeMounts\",\"value\":[{\"name\":\"coturn-certs\",\"readOnly\":true,\"mountPath\":\"/certs\"}]},{\"op\":\"add\",\"path\":\"/spec/template/spec/volumes\",\"value\":[{\"name\":\"coturn-certs\",\"secret\":{\"secretName\":\"sps-coturn-<REGION>-tls\"}}]},{\"op\":\"replace\",\"path\":\"/spec/template/spec/initContainers/0/env\",\"value\":[{\"name\":\"EXTERNAL_IP\",\"value\":\"turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud\"},{\"name\":\"PORT\",\"value\":\"443\"},{\"name\":\"NAMESPACE\",\"valueFrom\":{\"fieldRef\":{\"apiVersion\":\"v1\",\"fieldPath\":\"metadata.namespace\"}}},{\"name\":\"CREDENTIAL\",\"valueFrom\":{\"configMapKeyRef\":{\"name\":\"sps-coturn\",\"key\":\"credential\"}}}]},{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/args\",\"value\":[\"--log-file=stdout\",\"--external-ip=$(HOST_IP)\",\"--listening-ip=$(HOST_IP)\",\"--relay-ip=$(HOST_IP)\",\"--user=sps-coturn-user:$(CREDENTIAL)\",\"--server-name=turnserver\",\"--fingerprint\",\"--listening-port=443\",\"--tls-listening-port=443\",\"--min-port=49152\",\"--max-port=65535\",\"--verbose\",\"--realm=PixelStreaming\",\"--lt-cred-mech\",\"--no-multicast-peers\",\"--denied-peer-ip=0.0.0.0-0.255.255.255\",\"--denied-peer-ip=100.64.0.0-100.127.255.255\",\"--denied-peer-ip=127.0.0.0-127.255.255.255\",\"--denied-peer-ip=169.254.0.0-169.254.255.255\",\"--denied-peer-ip=172.16.0.0-172.31.255.255\",\"--denied-peer-ip=192.0.0.0-192.0.0.255\",\"--denied-peer-ip=192.0.2.0-192.0.2.255\",\"--denied-peer-ip=192.88.99.0-192.88.99.255\",\"--denied-peer-ip=198.18.0.0-198.19.255.255\",\"--denied-peer-ip=198.51.100.0-198.51.100.255\",\"--denied-peer-ip=203.0.113.0-203.0.113.255\",\"--denied-peer-ip=240.0.0.0-255.255.255.255\",\"--cert /certs/tls.crt\",\"--pkey /certs/tls.key\"]},{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env\",\"value\":[{\"name\":\"PORT\",\"value\":\"443\"},{\"name\":\"HOST_IP\",\"valueFrom\":{\"fieldRef\":{\"apiVersion\":\"v1\",\"fieldPath\":\"status.podIP\"}}},{\"name\":\"NAMESPACE\",\"valueFrom\":{\"fieldRef\":{\"apiVersion\":\"v1\",\"fieldPath\":\"metadata.namespace\"}}},{\"name\":\"CREDENTIAL\",\"valueFrom\":{\"configMapKeyRef\":{\"name\":\"sps-coturn\",\"key\":\"credential\"}}}]}]"
```

Once the command has been run it can take up to 2 mins for the sps-coturn pod to restart

### 4. Update the sps-config with the sps-coturn domain

Once the `<REGION>`, `<COREWEAVE_NAMESPACE>` and `<REST_API_ACCESS_KEY>` has been obtained and substituted in the following command it can be executed

**Linux**
```bash
curl --request PUT \
https://api.<COREWEAVE_NAMESPACE>.<REGION>.ingress.coreweave.cloud/api/v1/config \
--header "Content-Type: application/json" \
--header "x-token: `echo -n "<REST_API_ACCESS_KEY>" | base64`" \
--data '{"webrtc":{"iceServers":{"servers":[{"address":"turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud","port":443}]}}}'
```

**Windows Powershell**
```powershell
Invoke-WebRequest -Method PUT `
-Uri https://api.<COREWEAVE_NAMESPACE>.<REGION>.ingress.coreweave.cloud/api/v1/config `
-ContentType "application/json" `
-Headers @{"x-token"=[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("<REST_API_ACCESS_KEY>"))} `
-Body '{"webrtc":{"iceServers":{"servers":[{"address":"turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud","port":443}]}}}'
```

Once the command has been run it can take up to 5 mins for the turn server to be populated to current running applications

### 5. Adding the secure turn to the application

In order for the application to use secure turn the secure turn will need to be added to the custom ice servers list

1. When creating/updating an application the secure turn address needs to be added to the list of custom ice servers
2. Log into the SPS Dashboard
3. Create or Update an application
4. Select the `custom ice servers` tab on the left hand side
5. Press the `+` button to add a new entry
6. In the `URLs` input enter the following value substituting `<REGION>` and `<COREWEAVE_NAMESPACE>`  
`turns:turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud?transport=tcp`
7. In the `Username` field enter `sps-coturn-user`
8. In the `Credential` field enter the **output** as is from the following command

**Linux**
```bash
kubectl get configmap sps-coturn -o "jsonpath={.data['credential']}"
```

**Windows Powershell**
```powershell
kubectl get configmap sps-coturn -o "jsonpath={.data['credential']}"
```