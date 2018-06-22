#!/bin/bash

set -e

wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -

echo "deb http://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list

# ...then, update your local package index, then finally install the cf CLI

sudo apt-get update

sudo apt-get install cf-cli

echo $CF_APP
echo $CF_API 
echo $CF_ORG
echo $CF_SPACE
echo $CF_USERNAME
echo $CF_PASSWORD

cf api $CF_API

cf login -u $CF_USERNAME -p $CF_PASSWORD -o $CF_ORG -s $CF_SPACE

BLUE=${CF_APP}
GREEN="${BLUE}-G"
CURRENTPATH=$(pwd)

finally ()
{
  # we don't want to keep the sensitive information around
  rm $MANIFEST
}

on_fail () {
  finally
  echo "DEPLOY FAILED - you may need to check 'cf apps' and 'cf routes' and do manual cleanup"
}

MANIFEST=$(mktemp -t "${BLUE}_manifest.XXXXXXXXXX")
sudo cp ./manifest.yml $MANIFEST

#Replace the names
sudo sed -i -e "s/: ${BLUE}/: ${GREEN}/g" $MANIFEST

# set up try/catch
# http://stackoverflow.com/a/185900/358804
trap on_fail ERR

DOMAIN="cfapps.eu10.hana.ondemand.com" 

cf push -f $MANIFEST

url="\"https://${GREEN}.${DOMAIN}\""
echo "curl --fail -I -k ${url}"

tmpfile=$(mktemp /tmp/foo.XXXXXXXXXX)

wget -q  -O /tmp/foo.XXXXXXXXXX ${url} | grep '200' /tmp/foo.XXXXXXXXXX | wc -l

foo="`cat /tmp/foo.XXXXXXXXXX`"

if [foo eq 1]; then
   echo "You rock"
fi


cf routes | tail -n +4 | grep $BLUE | awk '{print $3" -n "$2}' | xargs -n 3 cf map-route $GREEN

cf delete $BLUE -f
cf rename $GREEN $BLUE
cf delete-route $DOMAIN -n $GREEN -f
finally
cf logout
echo "DONE"