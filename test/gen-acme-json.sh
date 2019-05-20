#!/bin/bash
# args: email hostname keyfile certfile
mail=$1
host=$2
keyfile=$3
certfile=$4

cat <<-!cat
{
  "Account": {
    "Email": "$mail",
    "Registration": {
      "body": {
        "status": "valid",
        "contact": [
          "mailto:$mail"
        ]
      },
      "uri": "https://acme-v02.api.letsencrypt.org/acme/acct/$RANDOM"
    },
    "PrivateKey": "$(sed '/^-----/d' $keyfile | sed ':a;N;$!ba;s/\n//g')",
    "KeyType": "2048"
  },
  "Certificates": [
    {
      "Domain": {
        "Main": "$host",
        "SANs": null
      },
      "Certificate": "$(base64 -w 0 $certfile)",
      "Key": "$(base64 -w 0 $keyfile)"
    }
  ],
  "HTTPChallenges": {},
  "TLSChallenges": {}
}
!cat
