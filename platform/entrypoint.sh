#!/bin/bash
set -e

### LETSENCRYPT-TOMCAT ###

if [ -z "$P12_FILE" ] ; then
    echo '$P12_FILE not set'
    exit 1
fi

if [ -z "$PKCS12_KEY_PASSWORD" ] ; then
    echo '$PKCS12_KEY_PASSWORD not set'
    exit 1
fi

if [ -z "$PKCS12_STORE_PASSWORD" ] ; then
    echo '$PKCS12_STORE_PASSWORD not set'
    exit 1
fi

# set timezone

if [ -n "$TZ" ] ; then
    export CATALINA_OPTS="$CATALINA_OPTS -Duser.timezone=$TZ"
fi

# ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
# echo $TZ > /etc/timezone

# change server configuration

P12_FILE_PARAM="--stringparam https.keystoreFile '$P12_FILE' "
PKCS12_KEY_PASSWORD_PARAM="--stringparam https.keystorePass '$PKCS12_KEY_PASSWORD' "
PKCS12_STORE_PASSWORD_PARAM="--stringparam https.keyPass '$PKCS12_STORE_PASSWORD' "

if [ -n "$HTTP_PORT" ] ; then
    HTTP_PORT_PARAM="--stringparam http.port '$HTTP_PORT' "
fi

if [ -n "$PROXY_HTTP_NAME" ] ; then
    PROXY_HTTP_NAME_PARAM="--stringparam http.proxyName '$PROXY_HTTP_NAME' "
fi

if [ -n "$PROXY_HTTP_PORT" ] ; then
    PROXY_HTTP_PORT_PARAM="--stringparam http.proxyPort '$PROXY_HTTP_PORT' "
fi

if [ -n "$HTTP_REDIRECT_PORT" ] ; then
    HTTP_REDIRECT_PORT_PARAM="--stringparam http.redirectPort '$HTTP_REDIRECT_PORT' "
fi

if [ -n "$HTTP_CONNECTION_TIMEOUT" ] ; then
    HTTP_CONNECTION_TIMEOUT_PARAM="--stringparam http.connectionTimeout '$HTTP_CONNECTION_TIMEOUT' "
fi

if [ -n "$HTTP_COMPRESSION" ] ; then
    HTTP_COMPRESSION_PARAM="--stringparam http.compression $HTTP_COMPRESSION "
fi

if [ -n "$HTTPS_PORT" ] ; then
    HTTPS_PORT_PARAM="--stringparam https.port '$HTTPS_PORT' "
fi

if [ -n "$HTTPS_MAX_THREADS" ] ; then
    HTTPS_MAX_THREADS_PARAM="--stringparam https.maxThreads '$HTTPS_MAX_THREADS' "
fi

if [ -n "$HTTPS_CLIENT_AUTH" ] ; then
    HTTPS_CLIENT_AUTH_PARAM="--stringparam https.clientAuth '$HTTPS_CLIENT_AUTH' "
fi

if [ -n "$PROXY_HTTPS_NAME" ] ; then
    PROXY_HTTPS_NAME_PARAM="--stringparam https.proxyName '$PROXY_HTTPS_NAME' "
fi

if [ -n "$PROXY_HTTPS_PORT" ] ; then
    PROXY_HTTPS_PORT_PARAM="--stringparam https.proxyPort '$PROXY_HTTPS_PORT' "
fi

if [ -n "$HTTPS_COMPRESSION" ] ; then
    HTTPS_COMPRESSION_PARAM="--stringparam https.compression $HTTPS_COMPRESSION "
fi

if [ -n "$KEY_ALIAS" ] ; then
    KEY_ALIAS_PARAM="--stringparam https.keyAlias '$KEY_ALIAS' "
fi

transform="xsltproc \
  --output conf/server.xml \
  $HTTP_PORT_PARAM \
  $PROXY_HTTP_NAME_PARAM \
  $PROXY_HTTP_PORT_PARAM \
  $HTTP_REDIRECT_PORT_PARAM \
  $HTTP_CONNECTION_TIMEOUT_PARAM \
  $HTTP_COMPRESSION_PARAM \
  $HTTPS_PORT_PARAM \
  $HTTPS_MAX_THREADS_PARAM \
  $HTTPS_CLIENT_AUTH_PARAM \
  $PROXY_HTTPS_NAME_PARAM \
  $PROXY_HTTPS_PORT_PARAM \
  $HTTPS_COMPRESSION_PARAM \
  $P12_FILE_PARAM \
  $PKCS12_KEY_PASSWORD_PARAM \
  $KEY_ALIAS_PARAM \
  $PKCS12_STORE_PASSWORD_PARAM \
  conf/letsencrypt-tomcat.xsl \
  conf/server.xml"

eval "$transform"

### PLATFORM ###

# check mandatory environmental variables (which are used in conf/ROOT.xml)

if [ -z "$PROXY_HOST" ] ; then
    echo '$PROXY_HOST not set'
    exit 1
fi

if [ -z "$TIMEOUT" ] ; then
    echo '$TIMEOUT not set'
    exit 1
fi

if [ -z "$PROTOCOL" ] ; then
    echo '$PROTOCOL not set'
    exit 1
fi

if [ -z "$PROXY_HTTP_PORT" ] ; then
    echo '$PROXY_HTTP_PORT not set'
    exit 1
fi

if [ -z "$PROXY_HTTPS_PORT" ] ; then
    echo '$PROXY_HTTPS_PORT not set'
    exit 1
fi

if [ -z "$HOST" ] ; then
    echo '$HOST not set'
    exit 1
fi

if [ -z "$ABS_PATH" ] ; then
    echo '$ABS_PATH not set'
    exit 1
fi

if [ -z "$CLIENT_KEYSTORE" ] ; then
    echo '$CLIENT_KEYSTORE not set'
    exit 1
fi

if [ -z "$SECRETARY_CERT_ALIAS" ] ; then
    echo '$SECRETARY_CERT_ALIAS not set'
    exit 1
fi

if [ -z "$CLIENT_TRUSTSTORE" ] ; then
    echo '$SECRETARY_CERT_ALIAS not set'
    exit 1
fi

if [ -z "$CLIENT_KEYSTORE_PASSWORD" ] ; then
    echo '$CLIENT_KEYSTORE_PASSWORD not set'
    exit 1
fi

if [ -z "$CLIENT_TRUSTSTORE_PASSWORD" ] ; then
    echo '$CLIENT_TRUSTSTORE_PASSWORD not set'
    exit 1
fi

if [ -z "$ATOMGRAPH_UPLOAD_ROOT" ] ; then
    echo '$ATOMGRAPH_UPLOAD_ROOT not set'
    exit 1
fi

if [ -z "$SIGN_UP_CERT_VALIDITY" ] ; then
    echo '$SIGN_UP_CERT_VALIDITY not set'
    exit 1
fi

if [ -z "$CONTEXT_DATASET" ] ; then
    echo '$CONTEXT_DATASET not set'
    exit 1
fi

if [ -z "$MAIL_SMTP_HOST" ] ; then
    echo '$MAIL_SMTP_HOST not set'
    exit 1
fi

if [ -z "$MAIL_SMTP_PORT" ] ; then
    echo '$MAIL_SMTP_PORT not set'
    exit 1
fi

if [ -z "$MAIL_USER" ] ; then
    echo '$MAIL_USER not set'
    exit 1
fi

# if server's SSL certificates do not exist (e.g. not mounted), generate them
# https://community.letsencrypt.org/t/cry-for-help-windows-tomcat-ssl-lets-encrypt/22902/4

if [ ! -f "$P12_FILE" ]; then
    if [ ! -d "$LETSENCRYPT_CERT_DIR" ] || [ -z "$(ls -A "$LETSENCRYPT_CERT_DIR")" ]; then
        printf "\n### Generating server certificate\n"

        # crude check if the host is an IP address
        IP_ADDR_MATCH=$(echo "$HOST" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" || test $? = 1)

        if [ -n "$IP_ADDR_MATCH" ]; then
            ext="SAN=IP:${HOST}" # IP address
        else
            ext="SAN=DNS:${HOST}" # hostname
        fi

        keytool \
          -genkeypair \
          -storetype PKCS12 \
          -alias "$KEY_ALIAS" \
          -keyalg RSA \
          -keypass "$PKCS12_KEY_PASSWORD" \
          -storepass "$PKCS12_STORE_PASSWORD" \
          -ext "$ext" \
          -dname "CN=${HOST},OU=LinkedDataHub,O=AtomGraph,L=Copenhagen,ST=Copenhagen,C=DK" \
          -keystore "$P12_FILE"
    else
        printf "\n### Converting provided LetsEncrypt fullchain.pem/privkey.pem to server certificate\n"

        openssl pkcs12 \
          -export \
          -in "$LETSENCRYPT_CERT_DIR"/fullchain.pem \
          -inkey "$LETSENCRYPT_CERT_DIR"/privkey.pem \
          -name "$KEY_ALIAS" \
          -out "$P12_FILE" \
          -password pass:"$PKCS12_KEY_PASSWORD"
    fi
else
    printf "\n### Server certificate exists\n"
fi

# construct base URI (ignore default HTTP and HTTPS ports)

if [ "$PROTOCOL" = "https" ]; then
    if [ "$PROXY_HTTPS_PORT" = 443 ]; then
        export BASE_URI="${PROTOCOL}://${HOST}${ABS_PATH}"
    else
        export BASE_URI="${PROTOCOL}://${HOST}:${PROXY_HTTPS_PORT}${ABS_PATH}"
    fi
else
    if [ "$PROXY_HTTP_PORT" = 80 ]; then
        export BASE_URI="http://${HOST}${ABS_PATH}"
    else
        export BASE_URI="http://${HOST}:${PROXY_HTTP_PORT}${ABS_PATH}"
    fi
fi

printf "\n### Base URI: %s\n" "$BASE_URI"

# create AtomGraph upload root

mkdir -p "$ATOMGRAPH_UPLOAD_ROOT"/"$UPLOAD_CONTAINER_PATH"

# functions that wait for other services to start

wait_for_host()
{
    local host="$1"
    local counter="$2"
    i=1

    while [ "$i" -le "$counter" ] && ! ping -c1 "$host" >/dev/null 2>&1
    do
        sleep 1 ;
        i=$(( i+1 ))
    done

    if ! ping -c1 "$host" >/dev/null 2>&1 ; then
        printf "\n### Host %s not responding after ${counter} retries, exiting..." "$host"
        exit 1
    else
        printf "\n### Host %s responded\n" "$host"
    fi
}

wait_for_url()
{
    local url="$1"
    local auth_user="$2"
    local auth_pwd="$3"
    local counter="$4"
    local accept="$5"
    i=1

    # use HTTP Basic auth if username/password are provided
    if [ -n "$auth_user" ] && [ -n "$auth_pwd" ] ; then
        while [ "$i" -le "$counter" ] && ! curl -s -f -X OPTIONS "$url" --user "$auth_user":"$auth_pwd" -H "Accept: ${accept}" >/dev/null 2>&1
        do
            sleep 1 ;
            i=$(( i+1 ))
        done

        if ! curl -s -f -X OPTIONS "$url" --user "$auth_user":"$auth_pwd" -H "Accept: ${accept}" >/dev/null 2>&1 ; then
            printf "\n### URL %s not responding after %s retries, exiting...\n" "$url" "$counter"
            exit 1
        else
            printf "\n### URL %s responded\n" "$url"
        fi
    else
        while [ "$i" -le "$counter" ] && ! curl -s -f -X OPTIONS "$url" -H "Accept: ${accept}"
        do
            sleep 1 ;
            i=$(( i+1 ))
        done

        if ! curl -s -f -X OPTIONS "$url" -H "Accept: ${accept}" >/dev/null 2>&1 ; then
            printf "\n### URL %s not responding after %s retries, exiting...\n" "$url" "$counter"
            exit 1
        else
            printf "\n### URL %s responded\n" "$url"
        fi
    fi
}

# function to extract a WebID-compatible modulus from a .p12 certificate

get_modulus()
{
    local cert_pem="$1"
    local password="$2"

    modulus_string=$(cat "$cert_pem" | openssl x509 -noout -modulus)
    modulus="${modulus_string##*Modulus=}" # cut Modulus= text
    echo "$modulus" | tr '[:upper:]' '[:lower:]' # lowercase
}

# function to append quad data to an RDF graph store

append_quads()
{
    local quad_store_url="$1"
    local auth_user="$2"
    local auth_pwd="$3"
    local filename="$4"
    local content_type="$5"

    # use HTTP Basic auth if username/password are provided
    if [ -n "$auth_user" ] && [ -n "$auth_pwd" ] ; then
        curl \
            -f \
            --basic \
            --user "$auth_user":"$auth_pwd" \
            "$quad_store_url" \
            -H "Content-Type: ${content_type}" \
            --data-binary @"$filename"
    else
        curl \
            -f \
            "$quad_store_url" \
            -H "Content-Type: ${content_type}" \
            --data-binary @"$filename"
    fi
}

# extract the quad store endpoint (and auth credentials) of the root app from the system dataset using SPARQL and XPath queries

envsubst '$BASE_URI' < select-root-services.rq.template > select-root-services.rq

# base the $CONTEXT_DATASET

webapp_context_dataset="/WEB-INF/classes/com/atomgraph/linkeddatahub/system.nq"
based_context_dataset="${PWD}/webapps/ROOT${webapp_context_dataset}"
trig --base="$BASE_URI" "$CONTEXT_DATASET" > "$based_context_dataset"

sparql --data="$based_context_dataset" --query="select-root-services.rq" --results=XML > root_service_metadata.xml

root_end_user_quad_store_url=$(cat root_service_metadata.xml | xmlstarlet sel -B -N srx="http://www.w3.org/2005/sparql-results#" -T -t -v "/srx:sparql/srx:results/srx:result/srx:binding[@name = 'endUserQuadStore']" -n)
root_end_user_service_auth_user=$(cat root_service_metadata.xml | xmlstarlet sel -B -N srx="http://www.w3.org/2005/sparql-results#" -T -t -v "/srx:sparql/srx:results/srx:result/srx:binding[@name = 'endUserAuthUser']" -n)
root_end_user_service_auth_pwd=$(cat root_service_metadata.xml | xmlstarlet sel -B -N srx="http://www.w3.org/2005/sparql-results#" -T -t -v "/srx:sparql/srx:results/srx:result/srx:binding[@name = 'endUserAuthPwd']" -n)
root_admin_base_uri=$(cat root_service_metadata.xml | xmlstarlet sel -B -N srx="http://www.w3.org/2005/sparql-results#" -T -t -v "/srx:sparql/srx:results/srx:result/srx:binding[@name = 'adminBaseUri']" -n)
root_admin_quad_store_url=$(cat root_service_metadata.xml | xmlstarlet sel -B -N srx="http://www.w3.org/2005/sparql-results#" -T -t -v "/srx:sparql/srx:results/srx:result/srx:binding[@name = 'adminQuadStore']" -n)
root_admin_service_auth_user=$(cat root_service_metadata.xml | xmlstarlet sel -B -N srx="http://www.w3.org/2005/sparql-results#" -T -t -v "/srx:sparql/srx:results/srx:result/srx:binding[@name = 'adminAuthUser']" -n)
root_admin_service_auth_pwd=$(cat root_service_metadata.xml | xmlstarlet sel -B -N srx="http://www.w3.org/2005/sparql-results#" -T -t -v "/srx:sparql/srx:results/srx:result/srx:binding[@name = 'adminAuthPwd']" -n)

rm -f root_service_metadata.xml select-root-services.rq

if [ -z "$root_end_user_quad_store_url" ] ; then
    printf "\nEnd-user quad store could not be extracted from %s for root app with base URI %s. Exiting...\n" "$CONTEXT_DATASET" "$BASE_URI"
    exit 1
fi
if [ -z "$root_admin_base_uri" ] ; then
    printf "\nAdmin base URI extracted from %s for root app with base URI %s. Exiting...\n" "$CONTEXT_DATASET" "$BASE_URI"
    exit 1
fi
if [ -z "$root_admin_quad_store_url" ] ; then
    printf "\nAdmin quad store could not be extracted from %s for root app with base URI %s. Exiting...\n" "$CONTEXT_DATASET" "$BASE_URI"
    exit 1
fi

printf "\n### Quad store URL of the root admin service: %s\n" "$root_admin_quad_store_url"

# generate root owner WebID certificate if $OWNER_KEYSTORE does not exist

get_webid_uri()
{
    local cert_pem="$1"
    local password="$2"

    openssl x509 -in "$cert_pem" -text -noout -passin pass:"$password" \
      -certopt no_subject,no_header,no_version,no_serial,no_signame,no_validity,no_issuer,no_pubkey,no_sigdump,no_aux \
      | awk '/X509v3 Subject Alternative Name/ {getline; print}' | xargs | tail -c +5
}

owner_keystore_pem="${OWNER_KEYSTORE}.pem"

if [ ! -f "$OWNER_KEYSTORE" ]; then
    if [ -z "$OWNER_MBOX" ] ; then
        echo '$OWNER_MBOX not set'
        exit 1
    fi

    if [ -z "$OWNER_GIVEN_NAME" ] ; then
        echo '$OWNER_GIVEN_NAME not set'
        exit 1
    fi

    if [ -z "$OWNER_FAMILY_NAME" ] ; then
        echo '$OWNER_FAMILY_NAME not set'
        exit 1
    fi

    if [ -z "$OWNER_ORG_UNIT" ] ; then
        echo '$OWNER_ORG_UNIT not set'
        exit 1
    fi

    if [ -z "$OWNER_ORGANIZATION" ] ; then
        echo '$OWNER_ORGANIZATION not set'
        exit 1
    fi

    if [ -z "$OWNER_LOCALITY" ] ; then
        echo '$OWNER_LOCALITY not set'
        exit 1
    fi

    if [ -z "$OWNER_STATE_OR_PROVINCE" ] ; then
        echo '$OWNER_STATE_OR_PROVINCE not set'
        exit 1
    fi

    if [ -z "$OWNER_COUNTRY_NAME" ] ; then
        echo '$OWNER_COUNTRY_NAME not set'
        exit 1
    fi

    if [ -z "$OWNER_KEY_PASSWORD" ] ; then
        echo '$OWNER_KEY_PASSWORD not set'
        exit 1
    fi

    root_owner_dname="CN=${OWNER_GIVEN_NAME} ${OWNER_FAMILY_NAME},OU=${OWNER_ORG_UNIT},O=${OWNER_ORGANIZATION},L=${OWNER_LOCALITY},ST=${OWNER_STATE_OR_PROVINCE},C=${OWNER_COUNTRY_NAME}"
    printf "\n### Root owner WebID certificate's DName attributes: %s\n" "$root_owner_dname"

    root_owner_uuid=$(uuidgen | tr '[:upper:]' '[:lower:]') # lowercase
    export root_owner_uuid
    OWNER_DOC_URI="${BASE_URI}admin/acl/agents/${root_owner_uuid}/"
    OWNER_URI="${OWNER_DOC_URI}#this"

    printf "\n### Root owner's WebID URI: %s\n" "$OWNER_URI"

    keytool \
        -genkeypair \
        -alias "$OWNER_CERT_ALIAS" \
        -keyalg RSA \
        -storetype PKCS12 \
        -keystore "$OWNER_KEYSTORE" \
        -storepass "$OWNER_KEY_PASSWORD" \
        -keypass "$OWNER_KEY_PASSWORD" \
        -dname "$root_owner_dname" \
        -ext SAN=uri:"$OWNER_URI" \
        -validity "$OWNER_CERT_VALIDITY"

    # convert owner's certificate to PEM

    openssl \
        pkcs12 \
        -in "$OWNER_KEYSTORE" \
        -passin pass:"$OWNER_KEY_PASSWORD" \
        -out "$owner_keystore_pem" \
        -passout pass:"$OWNER_KEY_PASSWORD"

    owner_cert_modulus=$(get_modulus "$owner_keystore_pem" "$OWNER_KEY_PASSWORD")
    export owner_cert_modulus
    printf "\n### Root owner WebID certificate's modulus: %s\n" "$owner_cert_modulus"

    public_key_uuid=$(uuidgen | tr '[:upper:]' '[:lower:]') # lowercase
    export public_key_uuid

    # append root owner metadata to the root admin dataset
    
    envsubst < split-default-graph.rq.template > split-default-graph.rq
    envsubst < root-owner.trig.template > root-owner.trig

    trig --base="$root_admin_base_uri" --output=nq root-owner.trig > root-owner.nq
    sparql --data root-owner.nq --base "$root_admin_base_uri" --query split-default-graph.rq | trig --output=nq > split.root-owner.nq

    printf "\n### Uploading the metadata of the owner agent...\n\n"

    append_quads "$root_admin_quad_store_url" "$root_admin_service_auth_user" "$root_admin_service_auth_pwd" split.root-owner.nq "application/n-quads"

    rm -f root-owner.trig root-owner.nq split.root-owner.nq
else
    OWNER_URI=$(get_webid_uri "$owner_keystore_pem" "$OWNER_KEY_PASSWORD")

    envsubst < split-default-graph.rq.template > split-default-graph.rq
fi

# extract admin/end-user bnodes or URIs from the $CONTEXT_DATASET

root_admin_app=$(grep "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/atomgraph/linkeddatahub/apps/domain#AdminApplication>" "$based_context_dataset" | cut -d " " -f 1)
root_end_user_app=$(grep "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/atomgraph/linkeddatahub/apps/domain#EndUserApplication>" "$based_context_dataset" | cut -d " " -f 1)

# append ownership metadata to apps

echo "${root_admin_app} <http://xmlns.com/foaf/0.1/maker> <${OWNER_URI}> ." >> "$based_context_dataset"
echo "${root_end_user_app} <http://xmlns.com/foaf/0.1/maker> <${OWNER_URI}> ." >> "$based_context_dataset"

# if CLIENT_TRUSTSTORE does not exist:
# 1. generate a secretary (server) certificate with a WebID relative to the BASE_URI
# 2. import the certificate into the CLIENT_TRUSTSTORE
# 3. initialize an Agent/PublicKey with secretary's metadata and key modulus
# 4. import the secretary metadata metadata into the quad store

SECRETARY_URI="${BASE_URI}${SECRETARY_REL_URI}"

if [ ! -f "$CLIENT_TRUSTSTORE" ]; then
    # generate secretary WebID certificate and extract its modulus

    secretary_dname="CN=LinkedDataHub,OU=LinkedDataHub,O=AtomGraph,L=Copenhagen,ST=Denmark,C=DK"

    printf "\n### Secretary's WebID URI: %s\n" "$SECRETARY_URI"

    keytool \
        -genkeypair \
        -alias "$SECRETARY_CERT_ALIAS" \
        -keyalg RSA \
        -storetype PKCS12 \
        -keystore "$CLIENT_KEYSTORE" \
        -storepass "$CLIENT_KEYSTORE_PASSWORD" \
        -keypass "$SECRETARY_KEY_PASSWORD" \
        -dname "$secretary_dname" \
        -ext SAN=uri:"$SECRETARY_URI" \
        -validity "$SECRETARY_CERT_VALIDITY"

    printf "\n### Secretary WebID certificate's DName attributes: %s\n" "$secretary_dname"

    # convert secretary's certificate to PEM

    client_keystore_pem="${CLIENT_KEYSTORE}.pem"

    openssl \
        pkcs12 \
        -in "$CLIENT_KEYSTORE" \
        -passin pass:"$SECRETARY_KEY_PASSWORD" \
        -out "$client_keystore_pem" \
        -passout pass:"$SECRETARY_KEY_PASSWORD"

    secretary_cert_modulus=$(get_modulus "$client_keystore_pem" "$SECRETARY_KEY_PASSWORD")
    export secretary_cert_modulus
    printf "\n### Secretary WebID certificate's modulus: %s\n" "$secretary_cert_modulus"

    # append secretary metadata to the root admin dataset

    envsubst < root-secretary.trig.template > root-secretary.trig

    trig --base="$root_admin_base_uri" --output=nq root-secretary.trig > root-secretary.nq
    sparql --data root-secretary.nq --base "$root_admin_base_uri" --query split-default-graph.rq | trig --output=nq > split.root-secretary.nq

    printf "\n### Waiting for %s...\n" "$root_admin_quad_store_url"

    wait_for_url "$root_admin_quad_store_url" "$root_admin_service_auth_user" "$root_admin_service_auth_pwd" "$TIMEOUT" "application/n-quads"

    printf "\n### Uploading the metadata of the secretary agent...\n\n"

    append_quads "$root_admin_quad_store_url" "$root_admin_service_auth_user" "$root_admin_service_auth_pwd" split.root-secretary.nq "application/n-quads"

    rm -f root-secretary.trig root-secretary.nq split.root-secretary.nq

    # if server certificate is self-signed, import it into client (secretary) truststore

    if [ "$SELF_SIGNED_CERT" = true ] ; then
      # export certficate

      keytool -exportcert \
        -alias "$KEY_ALIAS" \
        -file letsencrypt.cer \
        -keystore "$P12_FILE" \
        -storepass "$PKCS12_STORE_PASSWORD" \
        -storetype PKCS12

      printf "\n### Importing server certificate into client truststore\n\n"

      keytool -importcert \
        -alias "$KEY_ALIAS" \
        -file letsencrypt.cer \
        -keystore "$CLIENT_TRUSTSTORE" \
        -noprompt \
        -storepass "$CLIENT_KEYSTORE_PASSWORD" \
        -storetype PKCS12 \
        -trustcacerts
    fi

    # import default CA certs from the JRE

    export CACERTS="${JAVA_HOME}/lib/security/cacerts"

    keytool -importkeystore \
      -destkeystore "$CLIENT_TRUSTSTORE" \
      -deststorepass "$CLIENT_KEYSTORE_PASSWORD" \
      -deststoretype PKCS12 \
      -noprompt \
      -srckeystore "$CACERTS" \
      -srcstorepass changeit > /dev/null
fi

if [ -z "$LOAD_DATASETS" ]; then
    if [ ! -d /var/linkeddatahub/based-datasets ]; then
        LOAD_DATASETS=true
    else
        LOAD_DATASETS=false
    fi
fi

# load default admin/end-user datasets if we haven't yet created a folder with re-based versions of them (and then create it)
if [ "$LOAD_DATASETS" = "true" ]; then
    mkdir -p /var/linkeddatahub/based-datasets

    printf "\n### Loading default datasets into the end-user/admin triplestores...\n"

    envsubst < split-default-graph.rq.template > split-default-graph.rq

    trig --base="$BASE_URI" "$END_USER_DATASET" > /var/linkeddatahub/based-datasets/end-user.nq
    sparql --data /var/linkeddatahub/based-datasets/end-user.nq --base "$BASE_URI" --query split-default-graph.rq | trig --output=nq > /var/linkeddatahub/based-datasets/split.end-user.nq

    trig --base="$root_admin_base_uri" "$ADMIN_DATASET" > /var/linkeddatahub/based-datasets/admin.nq
    sparql --data /var/linkeddatahub/based-datasets/admin.nq --base "$root_admin_base_uri" --query split-default-graph.rq | trig --output=nq > /var/linkeddatahub/based-datasets/split.admin.nq

    wait_for_url "$root_end_user_quad_store_url" "$root_end_user_service_auth_user" "$root_end_user_service_auth_pwd" "$TIMEOUT" "application/n-quads"
    append_quads "$root_end_user_quad_store_url" "$root_end_user_service_auth_user" "$root_end_user_service_auth_pwd" /var/linkeddatahub/based-datasets/split.end-user.nq "application/n-quads"

    wait_for_url "$root_admin_quad_store_url" "$root_admin_service_auth_user" "$root_admin_service_auth_pwd" "$TIMEOUT" "application/n-quads"
    append_quads "$root_admin_quad_store_url" "$root_admin_service_auth_user" "$root_admin_service_auth_pwd" /var/linkeddatahub/based-datasets/split.admin.nq "application/n-quads"
fi

# change server configuration 
# the TrustManager code is located in lib/trust-manager.jar

TRUST_MANAGER_CLASS_NAME="com.atomgraph.linkeddatahub.server.ssl.TrustManager"

xsltproc \
  --output conf/server.xml \
  --stringparam https.trustManagerClassName "$TRUST_MANAGER_CLASS_NAME" \
  conf/server.xsl \
  conf/server.xml

# change context configuration

BASE_URI_PARAM="--stringparam aplc:baseUri '$BASE_URI' "
CLIENT_KEYSTORE_PARAM="--stringparam aplc:clientKeyStore 'file://$CLIENT_KEYSTORE' "
SECRETARY_CERT_ALIAS_PARAM="--stringparam aplc:secretaryCertAlias '$SECRETARY_CERT_ALIAS' "
CLIENT_TRUSTSTORE_PARAM="--stringparam aplc:clientTrustStore 'file://$CLIENT_TRUSTSTORE' "
CLIENT_KEYSTORE_PASSWORD_PARAM="--stringparam aplc:clientKeyStorePassword '$CLIENT_KEYSTORE_PASSWORD' "
CLIENT_TRUSTSTORE_PASSWORD_PARAM="--stringparam aplc:clientTrustStorePassword '$CLIENT_TRUSTSTORE_PASSWORD' "
ATOMGRAPH_UPLOAD_ROOT_PARAM="--stringparam aplc:uploadRoot 'file://$ATOMGRAPH_UPLOAD_ROOT' "
SIGN_UP_CERT_VALIDITY_PARAM="--stringparam aplc:signUpCertValidity '$SIGN_UP_CERT_VALIDITY' "
CONTEXT_DATASET_PARAM="--stringparam aplc:contextDataset '$webapp_context_dataset' "
MAIL_SMTP_HOST_PARAM="--stringparam mail.smtp.host '$MAIL_SMTP_HOST' "
MAIL_SMTP_PORT_PARAM="--stringparam mail.smtp.port '$MAIL_SMTP_PORT' "
MAIL_USER_PARAM="--stringparam mail.user '$MAIL_USER' "

if [ -n "$CACHE_MODEL_LOADS" ] ; then
    CACHE_MODEL_LOADS_PARAM="--stringparam a:cacheModelLoads '$CACHE_MODEL_LOADS' "
fi

# stylesheet URL must be relative to the base context URL
if [ -n "$STYLESHEET" ] ; then
    STYLESHEET_PARAM="--stringparam ac:stylesheet '$STYLESHEET' "
fi

if [ -n "$CACHE_STYLESHEET" ] ; then
    CACHE_STYLESHEET_PARAM="--stringparam ac:cacheStylesheet '$CACHE_STYLESHEET' "
fi

if [ -n "$RESOLVING_UNCACHED" ] ; then
    RESOLVING_UNCACHED_PARAM="--stringparam ac:resolvingUncached '$RESOLVING_UNCACHED' "
fi

if [ -n "$AUTH_QUERY" ] ; then
    AUTH_QUERY_PARAM="--stringparam aplc:authQuery '$AUTH_QUERY' "
fi

if [ -n "$OWNER_AUTH_QUERY" ] ; then
    OWNER_AUTH_QUERY_PARAM="--stringparam aplc:ownerAuthQuery '$OWNER_AUTH_QUERY' "
fi

if [ -n "$MAX_CONN_PER_ROUTE" ] ; then
    MAX_CONN_PER_ROUTE_PARAM="--stringparam aplc:maxConnPerRoute '$MAX_CONN_PER_ROUTE' "
fi

if [ -n "$MAX_TOTAL_CONN" ] ; then
    MAX_TOTAL_CONN_PARAM="--stringparam aplc:maxTotalConn '$MAX_TOTAL_CONN' "
fi

if [ -n "$IMPORT_KEEPALIVE" ] ; then
    IMPORT_KEEPALIVE_PARAM="--stringparam aplc:importKeepAlive '$IMPORT_KEEPALIVE' "
fi

if [ -n "$MAIL_PASSWORD" ] ; then
    MAIL_PASSWORD_PARAM="--stringparam mail.password '$MAIL_PASSWORD' "
fi

transform="xsltproc \
  --output conf/Catalina/localhost/ROOT.xml \
  $CACHE_MODEL_LOADS_PARAM \
  $STYLESHEET_PARAM \
  $CACHE_STYLESHEET_PARAM \
  $RESOLVING_UNCACHED_PARAM \
  $BASE_URI_PARAM \
  $CLIENT_KEYSTORE_PARAM \
  $SECRETARY_CERT_ALIAS_PARAM \
  $CLIENT_TRUSTSTORE_PARAM \
  $CLIENT_KEYSTORE_PASSWORD_PARAM \
  $CLIENT_TRUSTSTORE_PASSWORD_PARAM \
  $ATOMGRAPH_UPLOAD_ROOT_PARAM \
  $SIGN_UP_CERT_VALIDITY_PARAM \
  $CONTEXT_DATASET_PARAM \
  $AUTH_QUERY_PARAM \
  $OWNER_AUTH_QUERY_PARAM \
  $MAX_CONN_PER_ROUTE_PARAM \
  $MAX_TOTAL_CONN_PARAM \
  $IMPORT_KEEPALIVE_PARAM \
  $MAIL_SMTP_HOST_PARAM \
  $MAIL_SMTP_PORT_PARAM \
  $MAIL_USER_PARAM \
  $MAIL_PASSWORD_PARAM \
  conf/context.xsl \
  conf/Catalina/localhost/ROOT.xml"

eval "$transform"

# print Java's memory settings

java -XX:+PrintFlagsFinal -version | grep -iE 'HeapSize|PermSize|ThreadStackSize'

# wait for the end-user GSP service

printf "\n### Waiting for %s...\n" "$root_end_user_quad_store_url"

wait_for_url "$root_end_user_quad_store_url" "$root_end_user_service_auth_user" "$root_end_user_service_auth_pwd" "$TIMEOUT" "application/n-quads"

# wait for the admin GSP service

printf "\n### Waiting for %s...\n" "$root_admin_quad_store_url"

wait_for_url "$root_admin_quad_store_url" "$root_admin_service_auth_user" "$root_admin_service_auth_pwd" "$TIMEOUT" "application/n-quads"

# wait for the proxy server

printf "\n### Waiting for %s...\n" "$PROXY_HOST"

wait_for_host "$PROXY_HOST" "$TIMEOUT"

# set localhost to the nginx IP address - we want to loopback to it

proxy_ip=$(getent hosts "$PROXY_HOST" | awk '{ print $1 }')

echo "${proxy_ip} localhost" >> /etc/hosts

# run Tomcat (in debug mode if $JPDA_ADDRESS is defined)

if [ -z "$JPDA_ADDRESS" ] ; then
    catalina.sh run
else
    catalina.sh jpda run
fi