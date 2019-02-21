# Road map

## Build tests

Add more build tests.

Configure auto-test on docker hub

Configure build test on travis.

## AMaViS configuration

### support modifying what happens to spam

```
$final_spam_destiny       = D_PASS;
```

## OpenDMARK

Include in build target `auth` in Dockerfile

Add configuration function in entrypoint.sh

## Logging

ClamAV and FreshClam is writing some messages to stdout

## Support multiple domains

Requires modifications to configurations of Postfix, AMaViS and OpenDKIM, see https://forum.iredmail.org/topic10160-iredmail-support-multiple-domains-setup-issues-with-dkim-keys-amavisd-etc.html and https://blog.tinned-software.net/setup-postfix-for-multiple-domains/.

## Directory structures

Investigate if data and configuration directory structures can be arranged to simplify to make them persistent by mounting volumes

Might consider preventing environment variables to alter configurations if it exists.
