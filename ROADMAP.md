# Road map

## Directory structures

Investigate if data and configuration directory structures can be arranged to simplify to make them persistent by mounting volumes

Might consider preventing environment variables to alter configurations if it exists.

Preparing this implementation by saving config files during build stage (*.dist *.build) so that we can detect if config files has been modified. If they have; we will not touch them.

## OpenDMARK

Include in build target `milter` in Dockerfile

Add configuration function in entrypoint.sh

## Dovecot IMAP and POP3

Accommodate IMAP and POP3 configuration via environment variables