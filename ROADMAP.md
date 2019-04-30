# Road map

## Build tests

Add more build tests.

Configure auto-test on docker hub

Configure build test on travis.

## OpenDMARK

Include in build target `auth` in Dockerfile

Add configuration function in entrypoint.sh

## Support multiple domains

Requires modifications to configurations of Postfix, AMaViS and OpenDKIM, see https://forum.iredmail.org/topic10160-iredmail-support-multiple-domains-setup-issues-with-dkim-keys-amavisd-etc.html and https://blog.tinned-software.net/setup-postfix-for-multiple-domains/.

## Directory structures

Investigate if data and configuration directory structures can be arranged to simplify to make them persistent by mounting volumes

Might consider preventing environment variables to alter configurations if it exists.
