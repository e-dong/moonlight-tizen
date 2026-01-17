#!/bin/bash

# This is a prototype/proof-of-concept bash script for automating the install of moonlight
# to a Samsung tv running tizen os
# In this fork I plan to adding tizencertificates (https://github.com/sreyemnayr/tizencertificates)
# to generate certificates to populate in a docker volume.
#
# I will update the docker image entrypoint to do the following:
#   1. Allow user to generate certificates based on if docker volume is empty (no certs generated)
#      or certs are nearing expiration
#   2. Create security profile
#   3. Substitute passwords with empty string
#   4. unzip Moonlight.wgt, excluding existing signature files (since we will resign with our own profile)
#   5. Sign package 
#   6. Connect to TV (I will need to expose parameters to pass in TV's IP or hostname)
#   7. Check if moonlight is already installed, prompt user if they want to replace the existing installation
#   8. Install Moonlight app
#
# Until then, this script assumes certificates are already generated on the host

# Location of certs on the host machine
TIZEN_HOST_CERT_DIR="${HOME}/Apps/tizencertificates/certificates"
# Location of certs inside the container
TIZEN_CERT_DIR="/usr/local/share/tizencerts"

# Bind-mounting hardcoded host cert location
# Setting the network mode to host so PC is able to communicate with the TV
container_id="$(
  docker run -itd \
    -v "${TIZEN_HOST_CERT_DIR}":"${TIZEN_CERT_DIR}" \
    --network host \
    ghcr.io/brightcraft/moonlight-tizen:master
  )"
echo $container_id

docker exec ${container_id} \
  tizen security-profiles add \
    -A \
    --name mysamsung_profile \
    --author "${TIZEN_CERT_DIR}/author.p12" \
    --dist "${TIZEN_CERT_DIR}/distributor.p12" \
    --password '' \
    --dist-password ''

docker exec "${container_id}" \
  bash -c "sed -i 's|/usr/local/share/tizencerts/author.pwd||' /home/moonlight/tizen-studio-data/profile/profiles.xml"

docker exec "${container_id}" \
  bash -c "sed -i 's|/usr/local/share/tizencerts/distributor.pwd||' /home/moonlight/tizen-studio-data/profile/profiles.xml"

docker exec "${container_id}" \
  unzip -d /tmp/moonlight Moonlight.wgt -x *signature*.xml

docker exec -it "${container_id}" \
  bash -c 'tizen package -t wgt -s mysamsung_profile -- /tmp/moonlight'

docker exec -it "${container_id}" \
  sdb connect samsung

docker exec -it "${container_id}" \
  bash -c 'tizen install -n Moonlight.wgt -- /tmp/moonlight'

docker rm -f "${container_id}"
