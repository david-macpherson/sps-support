#!/bin/bash

set -e

NAMESPACE=""
REGION=""
SPS_RESTAPI_ACCESS_KEY=""


DOMAIN="turn-$REGION.$NAMESPACE.coreweave.cloud"
COTURN_CREDENTIAL=`kubectl get configmap sps-coturn -o "jsonpath={.data['credential']}"`
SECURE_TURN_URI="turns:$DOMAIN?transport=tcp"
SPS_API_URL=https://api.$NAMESPACE.$REGION.ingress.coreweave.cloud/api

echo "Update the service"
kubectl patch service sps-coturn --type='json' -p='[{"op":"add","path":"/metadata/annotations/external-dns.alpha.kubernetes.io~1hostname","value":"'${DOMAIN}'"}]'
echo "Create the certificate"

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: sps-coturn-$REGION-tls
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: sps-coturn-$REGION-tls
spec:
  dnsNames:
    - $DOMAIN
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: letsencrypt-prod
  secretName: sps-coturn-$REGION-tls
  usages:
    - digital signature
    - key encipherment
EOF

echo "Upated the deployment"
kubectl patch deployment sps-coturn --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/volumeMounts","value":[{"name":"coturn-certs","readOnly":true,"mountPath":"/certs"}]},{"op":"add","path":"/spec/template/spec/volumes","value":[{"name":"coturn-certs","secret":{"secretName":"sps-coturn-'$REGION'-tls"}}]},{"op":"replace","path":"/spec/template/spec/initContainers/0/env","value":[{"name":"EXTERNAL_IP","value":"'${DOMAIN}'"},{"name":"PORT","value":"443"},{"name":"NAMESPACE","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}},{"name":"CREDENTIAL","valueFrom":{"configMapKeyRef":{"name":"sps-coturn","key":"credential"}}}]},{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["--log-file=stdout","--external-ip=$(HOST_IP)","--listening-ip=$(HOST_IP)","--relay-ip=$(HOST_IP)","--user=sps-coturn-user:$(CREDENTIAL)","--server-name=turnserver","--fingerprint","--listening-port=443","--tls-listening-port=443","--min-port=49152","--max-port=65535","--verbose","--realm=PixelStreaming","--lt-cred-mech","--no-multicast-peers","--denied-peer-ip=0.0.0.0-0.255.255.255","--denied-peer-ip=100.64.0.0-100.127.255.255","--denied-peer-ip=127.0.0.0-127.255.255.255","--denied-peer-ip=169.254.0.0-169.254.255.255","--denied-peer-ip=172.16.0.0-172.31.255.255","--denied-peer-ip=192.0.0.0-192.0.0.255","--denied-peer-ip=192.0.2.0-192.0.2.255","--denied-peer-ip=192.88.99.0-192.88.99.255","--denied-peer-ip=198.18.0.0-198.19.255.255","--denied-peer-ip=198.51.100.0-198.51.100.255","--denied-peer-ip=203.0.113.0-203.0.113.255","--denied-peer-ip=240.0.0.0-255.255.255.255","--cert /certs/tls.crt","--pkey /certs/tls.key"]},{"op":"replace","path":"/spec/template/spec/containers/0/env","value":[{"name":"PORT","value":"443"},{"name":"HOST_IP","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"status.podIP"}}},{"name":"NAMESPACE","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}},{"name":"CREDENTIAL","valueFrom":{"configMapKeyRef":{"name":"sps-coturn","key":"credential"}}}]}]'

echo "Update SPS config"

curl --fail-with-body --request PUT \
$SPS_API_URL/v1/config \
--header "Content-Type: application/json" \
--header "x-token: `echo -n "$SPS_RESTAPI_ACCESS_KEY" | base64`" \
--data '{"webrtc":{"iceServers":{"servers":[{"address":"'$DOMAIN'","port":443}]}}}'

echo ""
echo ""
echo ""
echo "To enable secure turn add the following your application's custom ice server list"
echo ""
echo "URLs: $SECURE_TURN_URI"
echo ""
echo "Username:   sps-coturn-user"
echo "credential: $COTURN_CREDENTIAL"
echo ""




