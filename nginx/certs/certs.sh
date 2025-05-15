#!/bin/bash

set -euo pipefail  # Enforce strict error checking

# Sanitize input
DOMAIN="${1:?Domain name required}"
CLIENT_NAME="${2:?Client name required}"
[[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]] || { echo "Invalid domain"; exit 1; }
[[ "$CLIENT_NAME" =~ ^[a-zA-Z0-9]+$ ]] || { echo "Invalid client name"; exit 1; }

ALGORITHM="RSA -pkeyopt rsa_keygen_bits:4096"

# Set file paths for certificates and keys (relative to the current directory)
CA_KEY="ca_private.key"
CA_CERT="ca_certificate.crt"
SERVER_KEY="server_private.key"
SERVER_CERT="server_certificate.crt"
SERVER_CSR="server.csr"
CLIENT_KEY="client_private.key"
CLIENT_CERT="client_certificate.crt"
CLIENT_CSR="client.csr"
OPENSSL_CONF="openssl-san.cnf"  # Reference to the SAN config file

# Create dynamic OpenSSL configuration file with DOMAIN
cat > "$OPENSSL_CONF" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = MyOrg
OU = MyOrgUnit
CN = ${DOMAIN}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
IP.1 = 192.168.2.12  # Add the IP address here if needed
EOF

# Create the root Certificate Authority (CA)
echo "Creating Certificate Authority (CA)..."
openssl genpkey -algorithm $ALGORITHM -out $CA_KEY
openssl req -x509 -new -key $CA_KEY -out $CA_CERT -subj "/CN=${DOMAIN}" -days 3650

# Generate server private key and certificate using SAN config
echo "Generating server private key and certificate for ${DOMAIN}..."
openssl genpkey -algorithm $ALGORITHM -out $SERVER_KEY
openssl req -new -key $SERVER_KEY -out $SERVER_CSR -subj "/CN=${DOMAIN}"
openssl x509 -req -in $SERVER_CSR -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out $SERVER_CERT -days 730 -extensions v3_req -extfile $OPENSSL_CONF

# Generate client private key and certificate using SAN config
echo "Generating client private key and certificate for ${CLIENT_NAME}..."
openssl genpkey -algorithm $ALGORITHM -out $CLIENT_KEY
openssl req -new -key $CLIENT_KEY -out $CLIENT_CSR -subj "/CN=${CLIENT_NAME}"
openssl x509 -req -in $CLIENT_CSR -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out $CLIENT_CERT -days 730 -extensions v3_req -extfile $OPENSSL_CONF

echo "4096-bit RSA certificates created successfully!"
