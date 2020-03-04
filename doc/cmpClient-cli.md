# NAME

cmpClient - client for the Certificate Management Protocol (RFC4210)

# SYNOPSIS

**cmpClient** (**imprint|bootstrap|update|revoke|pkcs10**) \[**-section** _CA_\]

**cmpClient** _options_

\[**-help**\]
\[**-config** _filename_\]
\[**-section** _names_\]

\[**-server** _address\[:port\]_\]
\[**-proxy** _\[http://\]address\[:port\]\[/path\]_\]
\[**-no\_proxy** _addresses_\]
\[**-path** _remote\_path_\]
\[**-msgtimeout** _seconds_\]
\[**-totaltimeout** _seconds_\]

\[**-trusted** _filenames_\]
\[**-untrusted** _sources_\]
\[**-srvcert** _filename_\]
\[**-recipient** _name_\]
\[**-expect\_sender** _name_\]
\[**-ignore\_keyusage**\]
\[**-unprotectederrors**\]
\[**-extracertsout** _filename_\]
\[**-cacertsout** _filename_\]

\[**-ref** _value_\]
\[**-secret** _arg_\]
\[**-cert** _filename_\]
\[**-key** _filename_\]
\[**-keypass** _arg_\]
\[**-digest** _name_\]
\[**-mac** _name_\]
\[**-extracerts** _sources_\]
\[**-unprotectedrequests**\]

\[**-cmd** _ir|cr|kur|p10cr|rr_\]
\[**-infotype** _name_\]
\[**-geninfo** _OID_:int:_N_\]

\[**-newkeytype** EC:_curve_|RSA-_len_\]
\[**-newkey** _filename_\]
\[**-newkeypass** _arg_\]
\[**-subject** _name_\]
\[**-issuer** _name_\]
\[**-days** _number_\]
\[**-reqexts** _name_\]
\[**-sans** _spec_\]
\[**-san\_nodefault**\]
\[**-policies** _name_\]
\[**-policy\_oid** _names_\]
\[**-policy\_oids\_critical**\]
\[**-popo** _number_\]
\[**-csr** _filename_\]
\[**-out\_trusted** _filenames_\]
\[**-verify\_hostname** _cn_\]
\[**-verify\_ip** _ip_\]
\[**-verify\_email** _email_\]
\[**-implicitconfirm**\]
\[**-disableconfirm**\]
\[**-certout** _filename_\]

\[**-oldcert** _filename_\]
\[**-revreason** _number_\]

\[**-tls\_used**\]
\[**-tls\_cert** _filename_\]
\[**-tls\_key** _filename_\]
\[**-tls\_keypass** _arg_\]
\[**-tls\_extra** _filenames_\]
\[**-tls\_trusted** _filenames_\]
\[**-tls\_host** _name_\]

\[**-verbosity** _level_\]

\[**-check\_all**\]
\[**-check\_any**\]
\[**-crls** _URLs_\]
\[**-use\_cdp**\]
\[**-cdps** _URLs_\]
\[**-use\_aia**\]
\[**-ocsp** _URLs_\]
\[**-ocsp\_last**\]
\[**-stapling**\]

# DESCRIPTION

The **cmpClient** command is a demo and test client implementation for the Certificate
Management Protocol (CMP) as defined in RFC 4210.
It can be used to request certificates from a CA server,
update their certificates,
request certificates to be revoked, and perform other CMP requests.

# USAGE

- **imprint|bootstrap|update|revoke|pkcs10**

    Select demo `use_case` of the cmpClient application. The corresponding CMP request
    will be executed with default settings. These settings could be adapt via the
    file 'config/demo.cnf'.

- List of options available for the `cmpClient` application:

# OPTIONS

- **-help**

    Display a summary of all options

- **-config** _filename_

    Configuration file to use.
    An empty string `""` means none.
    Default filename is `config/demo.cnf`.

- **-section** _names_

    Section(s) to use within config file defining CMP options.
    An empty string `""` means no specific section.
    Default is `default`.
    Multiple section names may be given, separated by commas and/or whitespace.
    Contents of sections named later may override contents of sections named before.
    In any case, as usual, the `[default]` section and finally the unnamed
    section (as far as present) can provide per-option fallback values.

## Message transfer options

- **-server** _address\[:port\]_

    The IP address or DNS hostname and optionally port (defaulting to 80)
    of the CMP server to connect to using HTTP/S transport.

- **-proxy** _\[http://\]address\[:port\]\[/path\]_

    The HTTP(S) proxy server to use for reaching the CMP server unless **no\_proxy**
    applies, see below.
    The optional "http://" prefix and any trailing path are ignored.
    Defaults to the environment variable `http_proxy` if set, else `HTTP_PROXY`
    in case no TLS is used, otherwise `https_proxy` if set, else `HTTPS_PROXY`.

- **-no\_proxy** _addresses_
List of IP addresses and/or DNS names of servers not use an HTTP(S) proxy for,
separated by commas and/or whitespace.
Default is from the environment variable `no_proxy` if set, else `NO_PROXY`.
- **-path** _remote\_path_

    HTTP path at the CMP server (aka CMP alias) to use for POST requests.
    Defaults to "/".

- **-msgtimeout** _seconds_

    Number of seconds (or 0 for infinite) a CMP message round trip is
    allowed to take before a timeout error is returned.
    Default is 120.

- **-totaltimeout** _seconds_

    Maximum number seconds an enrollment may take, including attempts polling for
    certificates on `waiting` PKIStatus.
    Default is 0 (infinite).

## Server authentication options

- **-trusted** _filenames_

    When verifying signature-based protection of CMP response messages,
    these are the CA certificate(s) to trust while checking certificate chains
    during CMP server authentication.
    This option gives more flexibility than the **-srvcert** option because
    it does not pin down the expected CMP server by allowing only one certificate.

    Multiple filenames may be given, separated by commas and/or whitespace.
    Each source may contain multiple certificates.

- **-untrusted** _sources_

    Non-trusted intermediate certificate(s) that may be useful
    for building certificate chains when verifying
    the CMP server (when checking signature-based CMP message protection),
    the own TLS client cert (when constructing the TLS client cert chain),
    stapled OCSP responses (when establishing TLS connections),
    and/or the newly enrolled certificate.
    These may get added to the extraCerts field sent in requests as far as needed.

    Multiple filenames may be given, separated by commas and/or whitespace.
    Each file may contain multiple certificates.

- **-srvcert** _filename_

    The specific CMP server certificate to use and directly trust (even if it is
    expired) when verifying signature-based protection of CMP response messages.
    May be set alternatively to the **-trusted** option
    if the certificate is available and only this one shall be accepted.

    If set, the issuer of the certificate is also used as the recipient of the CMP
    request and as the expected sender of the CMP response,
    overriding any potential **-recipient** option.

- **-recipient** _name_

    Distinguished Name (DN) of the CMP message recipient,
    i.e., the CMP server (usually a CA or RA entity).

    The argument must be formatted as _/type0=value0/type1=value1/type2=..._,
    characters may be escaped by `\` (backslash), no spaces are skipped.

    If a CMP server certificate is given with the **-srvcert** option, its subject
    name is taken as the recipient name and the **-recipient** option is ignored.
    If neither of the two are given, the recipient of the PKI message is
    determined in the following order: from the **-issuer** option if present,
    the issuer of old cert given with the **-oldcert** option if present,
    the issuer of the client certificate (**-cert** option) if present.

    Setting the recipient field in the CMP header is mandatory.
    If none of the above options allowing to derive the recipient name is given,
    no suitable value for the recipient in the PKIHeader is available.
    As last resort it is set to NULL-DN.

    When a response is received, its sender must match the recipient of the request.

- **-expect\_sender** _name_

    Distinguished Name (DN) of the expected sender of CMP response messages when
    MSG\_SIG\_ALG is used for protection.
    This can be used to ensure that only a particular entity is accepted
    to act as CMP server, and attackers are not able to use arbitrary certificates
    of a trusted PKI hieararchy to fraudulently pose as CMP server.
    Note that this option gives slightly more freedom than **-srvcert**,
    which pins down the server to a particular certificate,
    while **-expect\_sender** _name_ will continue to match after updates of the
    server cert.

    The argument must be formatted as _/type0=value0/type1=value1/type2=..._,
    characters may be escaped by `\` (backslash), no spaces are skipped.

    If not given, the subject DN of **-srvcert**, if provided, will be used.

- **-ignore\_keyusage**

    Ignore key usage restrictions in CMP signer certificates when verifying
    signature-based protection of incoming CMP messages,
    else `digitalSignature` must be allowed for signer certificate.

- **-unprotectederrors**

    Accept missing or invalid protection of negative responses from the server.
    This applies to the following message types and contents:

    - error messages
    - negative certificate responses (IP/CP/KUP)
    - negative revocation responses (RP)
    - negative PKIConf messages

    **WARNING:** This setting leads to unspecified behavior and it is meant
    exclusively to allow interoperability with server implementations violating
    RFC 4210, e.g.:

    - section 5.1.3.1 allows exceptions from protecting only for special
    cases:
    "There MAY be cases in which the PKIProtection BIT STRING is deliberately not
    used to protect a message \[...\] because other protection, external to PKIX, will
    be applied instead."
    - section 5.3.21 is clear on ErrMsgContent: "The CA MUST always sign it
    with a signature key."
    - appendix D.4 shows PKIConf having protection

- **-extracertsout** _filename_

    The file where to save any extra certificates received in the extraCerts field
    of response messages.

- **-cacertsout** _filename_

    The file where to save any CA certificates received in the caPubs field of
    initializiation response (ip) messages.

## Client authentication options

- **-ref** _value_

    Reference number/string/value to use as fallback senderKID; this is required
    if no sender name can be determined from the **-cert** or <-subject> options and
    is typically used when authenticating with pre-shared key (password-based MAC).

- **-secret** _arg_

    Source of secret value to use for creating PBM-based protection of outgoing
    messages and for verifying any PBM-based protection of incoming messages.
    PBM stands for Password-Based Message Authentication Code.
    This takes precedence over the **-cert** option.

    Currently only plain passwords are supported,
    which should be preceded by "pass:".

- **-cert** _filename_

    The client's current certificate.
    Requires for the corresponding key to be given with **-key**.
    The subject of this certificate will be used as the "sender" field
    of outgoing CMP messages, while **-subjectName** may provide a fallback value.
    When using signature-based message protection, this "protection certificate"
    will be included first in the extraCerts field of outgoing messages.
    For IR this can be used for authenticating a request message
    using an external entity certificate as defined in appendix E.7 of RFC 4210.
    For KUR this is also used as certificate to be updated if the **-oldcert**
    option is not given.
    If the file includes further certs, they are appended to the untrusted certs.
    These may get added to the extraCerts field sent in requests as far as needed.

- **-key** _filename_

    The corresponding private key file for the client's current certificate given in
    the **-cert** option.
    This will be used for signature-based message protection
    unless the **-secret** option indicating PBM or **-unprotectedrequests** is given.

- **-keypass** _arg_

    Pass phrase source for the private key given with the **-key** option.
    Also used for **-cert** and **-oldcert** in case it is an encrypted PKCS#12 file.
    If not given here, the password will be prompted for if needed.

    Currently only plain passwords are supported,
    which should be preceded by "pass:".

- **-digest** _name_

    Specifies name of supported digest to use in RFC 4210's MSG\_SIG\_ALG
    and as the one-way function (OWF) in MSG\_MAC\_ALG.
    If applicable, this is used for message protection and
    Proof-of-Possession (POPO) signatures.
    To see the list of supported digests, use **openssl list -digest-commands**.
    Defaults to `sha256`.

- **-mac** _name_

    Specifies name of supported digest to use as the MAC algorithm in MSG\_MAC\_ALG.
    To get the names of supported MAC algorithms use **openssl list -mac-algorithms**
    and possibly combine such a name with the name of a supported digest algorithm,
    e.g., hmacWithSHA256.
    Defaults to `hmac-sha1` as per RFC 4210.

- **-extracerts** _sources_

    Certificates to append in the extraCerts field when sending messages.

    Multiple filenames or URLs may be given, separated by commas and/or whitespace.
    Each source may contain multiple certificates.

- **-unprotectedrequests**

    Send messages without CMP-level protection.

## Generic message options

- **-cmd** _ir|cr|kur|p10cr|rr_

    CMP command to execute. Overrides `use_case` if present.
    Currently implemented commands are:

    - ir    - Initialization Request
    - cr    - Certificate Request
    - p10cr - PKCS#10 Certification Request (for legacy support)
    - kur   - Key Update Request
    - rr    - Revocation Request

    **ir** requests initialization of an End Entity into a PKI hierarchy by means of
    issuance of a first certificate.

    **cr** requests issuance of an additional certificate for an End Entity already
    initialized to the PKI hierarchy.

    **p10cr** requests issuance of an additional certificate similarly to **cr**
    but uses PKCS#10 CSR format.

    **kur** requests (key) update for an existing, given certificate.

    **rr** requests revocation of an existing, given certificate.

- **-infotype** _name_

    Set InfoType name to use for requesting specific info in **genm**,
    e.g., `signKeyPairTypes`.

- **-geninfo** _OID_:int:_N_

    generalInfo integer values to place in request PKIHeader with given OID,
    e.g., `1.2.3:int:987`.

## Certificate enrollment options

- **-newkeytype** _spec_

    In case of IR, CR, or KUR,
    generate a new key of the given type for the requested certifiate.
    The _spec_ may be of the form "EC:_curve_" or "RSA-_length_".
    The key will be saved in the file specified with the **-newkey** option.

- **-newkey** _filename_

    The file to save the newly generated key (in case  **-newkeytype** is given).
    Otherwise the file to read the private or public key from
    for the certificate requested in IR, CR or KUR.
    Default is the current client key, if given.

- **-newkeypass** _arg_

    Pass phrase source for the key file given with the **-newkey** option.
    If not given here, the password will be prompted for if needed.

    Currently only plain passwords are supported,
    which should be preceded by "pass:".

- **-subject** _name_

    X509 Distinguished Name (DN) of subject to use in the requested certificate
    template.
    For KUR, it defaults to the subject DN of the reference certificate
    (see **-oldcert**).
    This default is used for IR and CR only if no SANs are set.

    The argument must be formatted as _/type0=value0/type1=value1/type2=..._,
    characters may be escaped by `\` (backslash), no spaces are skipped.

    In case **-cert** is not set, for instance when using MSG\_MAC\_ALG,
    the subject DN is also used as sender of the PKI message.

- **-issuer** _name_

    X509 issuer Distinguished Name (DN) of the CA server
    to place in the requested certificate template in IR/CR/KUR.

    The argument must be formatted as _/type0=value0/type1=value1/type2=..._,
    characters may be escaped by `\` (backslash), no spaces are skipped.

    If neither **-srvcert** nor **-recipient** is available,
    the name given in this option is also set as the recipient of the CMP message.

- **-days** _number_

    Number of days the new certificate is requested to be valid for, counting from
    the current time of the host.
    Also triggers the explicit request that the
    validity period starts from the current time (as seen by the host).

- **-reqexts** _name_

    Name of section in OpenSSL config file defining certificate request extensions.

- **-sans** _spec_

    One or more IP addresses, DNS names, or URIs separated by commas or whitespace,
    to add as Subject Alternative Name(s) (SAN) certificate request extension.
    If the special element "critical" is given the SANs are flagged as critical.
    Cannot be used if any Subject Alternative Name extension is set via **-reqexts**.

- **-san\_nodefault**

    When Subject Alternative Names are not given via **-sans**
    nor defined via **-reqexts**,
    they are copied by default from the reference certificate (see **-oldcert**).
    This can be disabled by giving the **-san\_nodefault** option.

- **-policies** _name_

    Name of section in OpenSSL config file defining policies to be set
    as certificate request extension.
    This option cannot be used together with **-policy\_oids**.

- **-policy\_oids** _names_

    One or more OID(s), separated by commas and/or whitespace,
    to add as certificate policies request extension.
    This option cannot be used together with **-policies**.

- **-policy\_oids\_critical**

    Flag the policies given with **-policy\_oids** as critical.

- **-popo** _number_

    Proof-of-Possession (POPO) method to use for IR/CR/KUR; values: `-1`..<2> where
    `-1` = NONE, `0` = RAVERIFIED, `1` = SIGNATURE (default), `2` = KEYENC.

    Note that a signature-based POPO can only produced if a private key
    is provided via the **-newkey** or **-key** options.

- **-csr** _filename_

    CSR in PKCS#10 format to use in P10CR.
    This is for supporting legacy clients.

- **-out\_trusted** _filenames_

    Trusted certificate(s) to use for verifying the newly enrolled certificate.

    Multiple filenames may be given, separated by commas and/or whitespace.
    Each source may contain multiple certificates.

- **-verify\_hostname** _name_

    When verification of the newly enrolled certificate is enabled (with the
    **-out\_trusted** option), check if any DNS Subject Alternative Name (or if no
    DNS SAN is included, the Common Name in the subject) equals the given **name**.

- **-verify\_ip** _ip_

    When verification of the newly enrolled certificate is enabled (with the
    **-out\_trusted** option), check if there is
    an IP address Subject Alternative Name matching the given IP address.

- **-verify\_email** _email_

    When verification of the newly enrolled certificate is enabled (with the
    **-out\_trusted** option), check if there is
    an email address Subject Alternative Name matching the given email address.

- **-implicitconfirm**

    Request implicit confirmation of newly enrolled certificates.

- **-disableconfirm**

    Do not send certificate confirmation message for newly enrolled certificate
    without requesting implicit confirmation
    to cope with broken servers not supporting implicit confirmation correctly.
    **WARNING:** This leads to behavior violating RFC 4210.

- **-certout** _filename_

    The file where the newly enrolled certificate should be saved.

## Certificate update and revocation options

- **-oldcert** _filename_

    The certificate to be updated (i.e., renewed or re-keyed) in KUR
    or to be revoked in RR.
    It must be given for RR, else it defaults to **-cert**.

    The reference certificate determined in this way, if any, is also used for
    deriving default subject DN and Subject Alternative Names for IR, CR, and KUR.
    Its issuer, if any, is used as default recipient in the CMP message header
    if neither **-srvcert**, **-recipient**, nor **-issuer** is available.

- **-revreason** _number_

    Set CRLReason to be included in revocation request (RR); values: `0`..`10`
    or `-1` for none (which is the default).

    Reason numbers defined in RFC 5280 are:

        CRLReason ::= ENUMERATED {
             unspecified             (0),
             keyCompromise           (1),
             cACompromise            (2),
             affiliationChanged      (3),
             superseded              (4),
             cessationOfOperation    (5),
             certificateHold         (6),
             -- value 7 is not used
             removeFromCRL           (8),
             privilegeWithdrawn      (9),
             aACompromise           (10)
         }

## TLS connection options

- **-tls\_used**

    Enable using TLS (even when other TLS\_related options are not set)
    when connecting to CMP server.

- **-tls\_cert** _filename_

    Client's TLS certificate.
    If the file includes further certificates,
    they are used for constructing the client cert chain provided to the TLS server.

- **-tls\_key** _filename_

    Private key for the client's TLS certificate.

- **-tls\_keypass** _arg_

    Pass phrase source for client's private TLS key **tls\_key**.
    Also used for **-tls\_cert** in case it is an encrypted PKCS#12 file.
    If not given here, the password will be prompted for if needed.

    Currently only plain passwords are supported,
    which should be preceded by "pass:".

- **-tls\_extra** _filenames_

    Extra certificates to provide to TLS server during TLS handshake

- **-tls\_trusted** _filenames_

    Trusted certificate(s) to use for verifying the TLS server certificate.
    This implies hostname validation.

    Multiple filenames may be given, separated by commas and/or whitespace.
    Each source may contain multiple certificates.

- **-tls\_host** _name_

    Address to be checked (rather than **-server** address)
    during TLS hostname validation.
    This may be a Common Name, a DNS name, or an IP address.

## Debugging options

- **-verbosity** _level_

    Level of verbosity for logging, error output, etc.
    0 = EMERG, 1 = ALERT, 2 = CRIT, 3 = ERR, 4 = WARN, 5 = NOTE,
    6 = INFO, 7 = DEBUG, 8 = TRACE.
    Defaults to 6 = INFO.
    The levels DEBUG and TRACE are most useful for certificate status check issues.

## Certificate status checking options, for both CMP and TLS

The following set of options determine various parameters of
certificate revocation status checking to be performed by the client
on setting up any TLS connection and on checking any signature-based protection
of CMP messages received, but not when verifying newly enrolled certificates.

Status checking is demanded if any of the status checking options are set.
Then by default only the leaf certificates of a chain are checked, i.e.,
the certificates of CMP servers and of TLS servers (as far as TLS is used).
The options **-check\_all** and **-check\_any** may be used to change the extent
of the checks to futher elements in the CA chain of these certificates.

For each certificate for which the status check is demanded the
certification verification procedure will try to obtain the revocation status
first via OCSP stapling if enabled,
then from any locally available CRLs,
then from any Online Certificate Status Protocol (OCSP) responders if enabled,
and finally from CRLs downloaded from certificate distribution points (CDPs)
if enabled.
With the **-ocsp\_last** option CDPs are tried before trying OCSP.
Verification fails if no valid and current revocation status can be found
or the status indicates that the certificate has been revoked.

- **-check\_all**

    Check certificate status not only for leaf certificates of a chain
    but for all certificates (except root, i.e., self-issued certificates).

- **-check\_any**

    Check certificate status for those certificates (except root certificates)
    that contain a CDP or AIA entry or for which OCSP stapling for TLS is enabled.

- **-crls** _URLs_

    Enable CRL-based status checking and
    use given CRL(s) as primary source of certificate revocation information.
    The URLs argument may contain a single element or
    a comma- or whitespace-separated list,
    each element starting with `http:` or `file:` or being a filename or pathname.

- **-use\_cdp**

    Enable CRL-based status checking and
    enable using CRL Distribution Points (CDP) extension entries in certificates.

- **-cdps** _URLs_

    Enable CRL-based status checking and
    use the given URL(s) as fallback certificate distribution points (CDP).

- **-use\_aia**

    Enable OCSP-based status checking and
    enable using Authority Information Access (AIA) OCSP responder entries
    in certificates.

- **-ocsp** _URLs_

    Enable OCSP-based status checking and
    use given OCSP responder URL(s) as fallback.

- **-ocsp\_last**

    If both OCSP-based checks and checks using CRLs downloaded from CDPs are enabled
    then do OCSP-based checks last (else before using CRLs downloaded from CDPs).

- **-stapling**

    Enable OCSP-based status checking and
    try using the TLS certificate status request extension ("OCSP stapling") first.
    So far OCSP multi-stapling is not supported,
    so status information can be obtained in this way only for the leaf certificate
    (i.e., the TLS server certificate).

## Certificate validation options, for both CMP and TLS

- **-policy**, **-purpose**, **-verify\_name**, **-verify\_depth**,
**-attime**,
**-ignore\_critical**,
**-policy\_check**,
**-explicit\_policy**, **-inhibit\_any**, **-inhibit\_map**,
**-x509\_strict**, **-extended\_crl**, **-use\_deltas**,
**-policy\_print**, **-check\_ss\_sig**, **-trusted\_first**,
**-suiteB\_128\_only**, **-suiteB\_128**, **-suiteB\_192**,
**-partial\_chain**,
**-no\_check\_time**,
**-auth\_level**,
**-allow\_proxy\_certs**

    Set various options of certificate chain verification.
    See the [openssl-verify(1)](http://man.he.net/man1/openssl-verify) manual page
    or ["Verification Options" in openssl(1)](http://man.he.net/man1/openssl) for details.

# COPYRIGHT

Copyright (c) 2020 Siemens AG.

Licensed under the Apache License, Version 2.0
SPDX-License-Identifier: Apache-2.0