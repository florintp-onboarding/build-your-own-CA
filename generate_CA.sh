#!/bin/bash

# Create CA and CRL URLs
export VAULT_ADDR=http://127.0.0.1:8200
vault login
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki

vault write -field=certificate pki/root/generate/internal \
common_name="example.com" \
issuer_name="root-2022" \
ttl=87600h > root_2022_ca.crt

vault list pki/issuers/

vault read pki/issuer/$(vault list pki/issuers/|tail -n1) | tail -n6

vault write pki/roles/2022-servers allow_any_name=true

vault write pki/config/urls \
issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

# Create Intermediate CA
vault secrets enable -path=pki_int pki

vault secrets tune -max-lease-ttl=43800h pki_int

vault write -format=json pki_int/intermediate/generate/internal \
common_name="example.com Intermediate Authority" \
issuer_name="example-dot-com-intermediate" \
 > pki_intermediate.csr_full

cat pki_intermediate.csr_full|grep csr |sed 's/\\n/\n/g ; s/"//g ; s/\,//g ; s/.csr:// ; s/    //g' > pki_intermediate.csr

vault write -format=json pki/root/sign-intermediate \
issuer_ref="root-2022" \
csr=@pki_intermediate.csr \
format=pem_bundle ttl="43800h" \
 > intermediate.cert.pem_full


cat intermediate.cert.pem_full |grep '"certificate":'|sed 's/\\n/\n/g ; s/"//g ; s/\,//g ; s/.certificate:// ; s/    //g' > intermediate.cert.pem

vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
