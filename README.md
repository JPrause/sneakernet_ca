# sneakernet ca

When it is not possible to use a real CA like Red Hat IdM,
sneakernet is available to allow you to manually copy certificates around.

This plugs into certmonger to allow you to upgrade to ipa once a Proof of Concept is
ready to go into production and use a real CA.

Again, it is advised to use a real CA in production like Red Hat IdM or freeipa.

# workflow

- local machine:
  + `getcert -c sneakernet ...` to generate keys/csr
  + scp /var/lib/sneakernet/* signing_computer:/tmp/requests
- signing_computer:
  + cd /tmp/requests ; sneakernet_sign
- local machine:
  + getcert refresh-ca sneakernet # if you have not done this before, load root ca certificate
  + scp signing_computer:/tmp/requests/\* /var/run/sneakernet/
  + getcert refresh -a # to tell certmonger to check requests
  + # do a quick check that certs have been moved around
  + rm /var/lib/sneakernet/*.{csr,crt}

# notes

- currently does NOT re-issue certificates ca properly
- only tested to run as root
