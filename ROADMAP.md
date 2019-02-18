# Roadmap

## Build test

add more build test and try to configure auto-test on docker hub.

## AMaViS configuration

### support modifying what happens to spam

```
$final_spam_destiny       = D_PASS;
```

## OpenDMARK

include in build target `auth` in Dockerfile

add configuration function in entrypoint.sh

## Logging

ClamAV and FreshClam is writing some messages to stdout

## Support multiple domains

requires modifications to configurations of Postfix, AMaViS and OpenDKIM, see https://forum.iredmail.org/topic10160-iredmail-support-multiple-domains-setup-issues-with-dkim-keys-amavisd-etc.html and https://blog.tinned-software.net/setup-postfix-for-multiple-domains/.

## Directory structures

Investigate if data and configuration directory structures can be arranged to simplify to make them persistent by mounting volumes

Might consider preventing environment variables to alter configurations if it exists.
