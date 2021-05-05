# Road map

## Switching to Rspamd in separate container

Firstly, Amavis is growing old and issues with maintaining functionality is starting to appear.
Fortunately, Rspamd is a modern mail filter with builtin web interface and under active development.

Secondly, now in retrospect, there is little reason to keep the mail transfer agent (Postfix) and the mail filter (Amavis/Rspamd) in the same container. Since they can easily be separated are linked by a simple interface.

So going forward efforts will be focused on moving to a `mlan/postfix` and a `mlan/rspamd` repository.
