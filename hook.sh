#!/usr/bin/env bash

prefix="_acme-challenge."

if [[ ! -f "${PWD}/hooks/cfhookbash/config.sh" ]]; then
    if [[ -f "${PWD}/config.sh" ]]; then
        configFile="${PWD}/config.sh";
    fi
else
    configFile="${PWD}/hooks/cfhookbash/config.sh";
fi


deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    . "${configFile}"
    if [[ -z "${ROOT_DIR}" ]];then
        rootDirectory="${PWD}/hooks/cfhookbash";
    else
        rootDirectory="${ROOT_DIR}";
    fi

curl -k -s "${dnsmanager_uri}?authinfo=${user}:${pass}&func=domain.record.edit&plid=${1}&name=${prefix}&value=${3}&ttl=60&rtype=txt&out=xml&sok=ok" \
        -o "${rootDirectory}/${1}.txt"

    # Add delay to get the new DNS record
    local DELAY=60;
    echo "+++ Wait for ${DELAY} seconds. +++";
    while [ $DELAY -gt 0 ]; do
        sleep 1;
       : $((DELAY--))
    done


    # This hook is called once for every domain that needs to be
    # validated, including any alternative names you may have listed.
    #
    # Parameters:
    # - DOMAIN
    #   The domain name (CN or subject alternative name) being
    #   validated.
    # - TOKEN_FILENAME
    #   The name of the file containing the token to be served for HTTP
    #   validation. Should be served by your web server as
    #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
    # - TOKEN_VALUE
    #   The token value that needs to be served for validation. For DNS
    #   validation, this is what you want to put in the _acme-challenge
    #   TXT record. For HTTP validation it is the value that is expected
    #   be found in the $TOKEN_FILENAME file.

    # Simple example: Use nsupdate with local named
    # printf 'server 127.0.0.1\nupdate add _acme-challenge.%s 300 IN TXT "%s"\nsend\n' "${DOMAIN}" "${TOKEN_VALUE}" | nsupdate -k /var/run/named/session.key
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    . "${configFile}"

    if [[ -z "${ROOT_DIR}" ]];then
        rootDirectory="${PWD}/hooks/cfhookbash";
    else
        rootDirectory="${ROOT_DIR}";
    fi

    key_value=$(grep -Po '"id":.*?[^\\]"' "${rootDirectory}/${1}.txt")
    #printf "id: %s\n" "${key_value}"
    #Remove first 6 occurence
    id="${key_value:6}"
    #printf "id: %s\n" "${id}"
    #Remove last char
    id="${id:-1}"
    #printf "id: %s\n" "${id}"

curl -k -s "${dnsmanager_uri}?authinfo=${user}:${pass}&func=domain.record.delete&plid=${1}&name=${prefix}${1}&value=${3}&ttl=60&rtype=txt&out=xml&sok=ok"
     rm "${rootDirectory}/${1}.txt"

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.

    # Simple example: Use nsupdate with local named
    # printf 'server 127.0.0.1\nupdate delete _acme-challenge.%s TXT "%s"\nsend\n' "${DOMAIN}" "${TOKEN_VALUE}" | nsupdate -k /var/run/named/session.key
}

deploy_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"

    if [[ -z "${ROOT_DIR}" ]];then
        rootDirectory="${PWD}/hooks/cfhookbash";
    else
        rootDirectory="${ROOT_DIR}";
    fi

    . "${rootDirectory}/deploy.sh"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - TIMESTAMP
    #   Timestamp when the specified certificate was created.

    # Simple example: Copy file to nginx config
    # cp "${KEYFILE}" "${FULLCHAINFILE}" /etc/nginx/ssl/; chown -R nginx: /etc/nginx/ssl
    # systemctl reload nginx
}

deploy_ocsp() {
    local DOMAIN="${1}" OCSPFILE="${2}" TIMESTAMP="${3}"

    # This hook is called once for each updated ocsp stapling file that has
    # been produced. Here you might, for instance, copy your new ocsp stapling
    # files to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - OCSPFILE
    #   The path of the ocsp stapling file
    # - TIMESTAMP
    #   Timestamp when the specified ocsp stapling file was created.

    # Simple example: Copy file to nginx config
    # cp "${OCSPFILE}" /etc/nginx/ssl/; chown -R nginx: /etc/nginx/ssl
    # systemctl reload nginx
}


unchanged_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
}

invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"

    # This hook is called if the challenge response has failed, so domain
    # owners can be aware and act accordingly.ls
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - RESPONSE
    #   The response that the verification server returned

    # Simple example: Send mail to root
    # printf "Subject: Validation of ${DOMAIN} failed!\n\nOh noez!" | sendmail root
}

request_failure() {
    local STATUSCODE="${1}" REASON="${2}" REQTYPE="${3}" HEADERS="${4}"

    # This hook is called when an HTTP request fails (e.g., when the ACME
    # server is busy, returns an error, etc). It will be called upon any
    # response code that does not start with '2'. Useful to alert admins
    # about problems with requests.
    #
    # Parameters:
    # - STATUSCODE
    #   The HTML status code that originated the error.
    # - REASON
    #   The specified reason for the error.
    # - REQTYPE
    #   The kind of request that was made (GET, POST...)
    # - HEADERS
    #   HTTP headers returned by the CA

    # Simple example: Send mail to root
    # printf "Subject: HTTP request failed failed!\n\nA http request failed with status ${STATUSCODE}!" | sendmail root
}

generate_csr() {
    local DOMAIN="${1}" CERTDIR="${2}" ALTNAMES="${3}"

    # This hook is called before any certificate signing operation takes place.
    # It can be used to generate or fetch a certificate signing request with external
    # tools.
    # The output should be just the cerificate signing request formatted as PEM.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain as specified in domains.txt. This does not need to
    #   match with the domains in the CSR, it's basically just the directory name.
    # - CERTDIR
    #   Certificate output directory for this particular certificate. Can be used
    #   for storing additional files.
    # - ALTNAMES
    #   All domain names for the current certificate as specified in domains.txt.
    #   Again, this doesn't need to match with the CSR, it's just there for convenience.

    # Simple example: Look for pre-generated CSRs
    # if [ -e "${CERTDIR}/pre-generated.csr" ]; then
    #   cat "${CERTDIR}/pre-generated.csr"
    # fi
}

startup_hook() {
  # This hook is called before the cron command to do some initial tasks
  # (e.g. starting a webserver).

  :
}

exit_hook() {
  # This hook is called at the end of the cron command and can be used to
  # do some final (cleanup or other) tasks.

  :
}

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|deploy_ocsp|unchanged_cert|invalid_challenge|request_failure|generate_csr|startup_hook|exit_hook)$ ]]; then
  "$HANDLER" "$@"
fi
