# Phase 4 - Mattermost Administration

## Objective

Learn Mattermost teams, users, channels, permissions,
messaging, direct messages and file storage.

## Team

- Team: dturn

## Users

- Administrator
- devops-user
- developer-user

## Public Channels

- Town Square
- Off-Topic
- devops
- development
- infrastructure
- monitoring
- alerts

## Private Channels

- devops-private

## Tests Performed

- [ ] Public channel messaging
- [ ] Private channel access
- [ ] Direct messaging
- [ ] Mentions
- [ ] Threads
- [ ] File upload
- [ ] Realtime messaging

## CLI Verification

```bash
docker compose exec mattermost \
  /mattermost/bin/mmctl --local user list

docker compose exec mattermost \
  /mattermost/bin/mmctl --local team list

docker compose exec mattermost \
  /mattermost/bin/mmctl --local channel list


Save it.

---

# Phase 4 checkpoint

We're almost finished with this phase.

Please complete:

```text
[✓] janagan
[✓] devops-user
[✓] developer-user
[✓] Add users to dturn

[ ] devops
[ ] development
[ ] infrastructure
[ ] monitoring
[ ] alerts
[ ] devops-private

[ ] Test public channel
[ ] Test private channel
[ ] Test direct message
[ ] Test mention
[ ] Test thread
[ ] Test file upload
